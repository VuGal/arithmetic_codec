// main parameters of the codec
parameter DECODER_PRECISION = 32;
parameter DECODER_NUM_OF_SYMBOLS = 257;
parameter DECODER_EOF_SYMBOL = 256;

// helper parameter
parameter LOG2_OF_DECODER_NUM_OF_SYMBOLS = $clog2(DECODER_NUM_OF_SYMBOLS);

module arithmetic_decoder (
    input uwire clk,
	input uwire rstn,
    input logic start,
    input logic readSuccess,
    input logic newBitsProvided,
	input logic [31:0] inputBits,
	output logic idle,
    output logic resultReady,
    output logic newBitsRequested,
    output logic [2:0] validOutputBytes,
    output logic [31:0] out
);

// divider IP
logic divisor_tvalid;
logic divisor_tready;
logic [DECODER_PRECISION-3:0] divisor_tdata;
logic dividend_tvalid;
logic dividend_tready;
logic [(DECODER_PRECISION*2)-3:0] dividend_tdata;
logic dout_tvalid;
logic [(DECODER_PRECISION*2)-3:0] dout_tdata;

divider divider_inst (clk, rstn, divisor_tvalid, divisor_tready, divisor_tdata, dividend_tvalid, 
                      dividend_tready, dividend_tdata, dout_tvalid, dout_tdata);

// probabilistic model
logic [DECODER_PRECISION-4:0] frequencyCounter [0:DECODER_NUM_OF_SYMBOLS-1];
logic [DECODER_PRECISION-4:0] freqBegin [0:DECODER_NUM_OF_SYMBOLS-1];
logic [DECODER_PRECISION-4:0] freqEnd [0:DECODER_NUM_OF_SYMBOLS-1];
logic [DECODER_PRECISION-4:0] totalFrequencyCounter;

// values determining interval width
logic [DECODER_PRECISION-1:0] whole;
logic [DECODER_PRECISION-2:0] threeQuarters;
logic [DECODER_PRECISION-2:0] half;
logic [DECODER_PRECISION-3:0] quarter;

// values determining subinterval
logic [DECODER_PRECISION-2:0] a;
logic [2*(DECODER_PRECISION-2):0] aTemp;
logic [DECODER_PRECISION-1:0] b;
logic [2*(DECODER_PRECISION-1):0] bTemp;
logic [DECODER_PRECISION-1:0] w;

// registers used in frequencies halving logic
logic [LOG2_OF_DECODER_NUM_OF_SYMBOLS-1:0] halveFrequenciesSymbolIndex;
logic [DECODER_PRECISION-4:0] halveFrequenciesHelperCounter;

// finite state machine of the decoder
enum logic [3:0] {
				IDLE = 0,
				NEW_SUBINTERVAL_1 = 1,
                NEW_SUBINTERVAL_2 = 2,
                NEW_SUBINTERVAL_3 = 3,
                CHECK_IF_SYMBOL_FOUND = 4,
                NEW_SUBINTERVAL_4 = 5,
				FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL = 6,
				RESCALE = 7,
                HALVE_FREQUENCIES_1 = 8,
                HALVE_FREQUENCIES_2 = 9,
                WAIT_FOR_READ_ACK = 10,
				READ_ACKNOWLEDGED = 11,
                WAIT_FOR_NEW_BITS = 12,
				NEW_BITS_PROVIDED = 13
				} 
currentState, nextState;

// register for decoder input bits
logic [DECODER_PRECISION-2:0] z;

// helper registers used in determining current bits/bytes for operations
logic [4:0] zCurrentBit;
logic [1:0] outCurrentByte;

// register storing current symbol
logic [LOG2_OF_DECODER_NUM_OF_SYMBOLS-1:0] currentSymbol;


always_ff @ (posedge clk) begin

	if (!rstn) begin

        // initialize interval values according to set precision
        whole <= (1 << (DECODER_PRECISION-1));
        threeQuarters <= (3 << (DECODER_PRECISION-3));
        half <= (1 << (DECODER_PRECISION-2));
        quarter <= (1 << (DECODER_PRECISION-3));
		
        // initialize FSM
		currentState <= IDLE;
        
        // initialize decoder outputs
        idle <= 1;
        resultReady <= 0;
        newBitsRequested <= 0;
        out <= 0;
	
	end else begin

        unique case (currentState) inside

            IDLE: begin

                // reset all registers to their proper initial values
                a <= 0;
                b <= whole;
                w <= whole;

                outCurrentByte <= 0;
                zCurrentBit <= DECODER_PRECISION-1;

                idle <= 1;
                validOutputBytes <= 4;

                // set all symbols' frequencies to 1 (setting to 0 would result in no subinterval assigned to the symbol)
                for (int i = 0; i < DECODER_NUM_OF_SYMBOLS; ++i) begin
                    frequencyCounter[i] <= 1;
                    freqBegin[i] <= i;
                    freqEnd[i] <= i+1;
                end
                totalFrequencyCounter <= DECODER_NUM_OF_SYMBOLS;

                if (start == 1) begin       // 'start' input triggered - start the operation of decoder
                    
                    currentState <= NEW_SUBINTERVAL_1;
                    idle <= 0;
                    currentSymbol <= 0;

                    // initialize as many 'z' bits as precision allows
                    for (int i = 0; i <= DECODER_PRECISION-2; ++i) begin
                        z[DECODER_PRECISION-2-i] <= inputBits[i];
                    end
                    
                end

            end
            
            NEW_SUBINTERVAL_1: begin

                // multiplication operation
                bTemp <= (w * freqEnd[currentSymbol]);
                aTemp <= (w * freqBegin[currentSymbol]);
                currentState <= NEW_SUBINTERVAL_2;

            end

            NEW_SUBINTERVAL_2: begin

                // first division operation (subinterval end) - pass values to divider IP inputs and set their "valid" AXI-Stream signals
                dividend_tdata <= bTemp;
                dividend_tvalid <= 1;
                divisor_tdata <= totalFrequencyCounter;
                divisor_tvalid <= 1;
                currentState <= NEW_SUBINTERVAL_3;

            end

            NEW_SUBINTERVAL_3: begin

                // clear inputs' "valid" AXI-Stream signals
                dividend_tvalid <= 0;
                divisor_tvalid <= 0;

                // wait for output's "valid" AXI-Stream signal indicating completion of the division operation
                if (dout_tvalid) begin

                    b <= a + dout_tdata;                        // set new subinterval end value using divider output
                    currentState <= CHECK_IF_SYMBOL_FOUND;      // check if calculated subinterval end is greater than 'z'

                end

            end

            CHECK_IF_SYMBOL_FOUND: begin

				if (b > z) begin    // symbol found - emit decoded symbol
                    currentState <= NEW_SUBINTERVAL_4;
                    dividend_tdata <= aTemp;
                    dividend_tvalid <= 1;
                    divisor_tvalid <= 1;
				end

				else begin
					currentState <= NEW_SUBINTERVAL_1;
					currentSymbol <= currentSymbol + 1;
				end

			end

            NEW_SUBINTERVAL_4: begin

                // clear inputs' "valid" AXI-Stream signals
				dividend_tvalid <= 0;
                divisor_tvalid <= 0;

                // wait for output's "valid" AXI-Stream signal indicating completion of the division operation
                if (dout_tvalid) begin

                    a <= a + dout_tdata;        // set new subinterval start value using divider output
                    currentState <= FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL;

                end

			end

            FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL: begin

                if (currentSymbol != DECODER_EOF_SYMBOL) begin

					if (totalFrequencyCounter == quarter-1) begin       // sum of frequency counts reached the limit - perform frequencies halving

						totalFrequencyCounter <= 0;
						halveFrequenciesSymbolIndex <= 0;
        				halveFrequenciesHelperCounter <= 0;
						currentState <= HALVE_FREQUENCIES_1;

					end

					else begin
					
                        // update probabilistic model
						frequencyCounter[currentSymbol] <= frequencyCounter[currentSymbol] + 1;
						freqEnd[currentSymbol] <= freqEnd[currentSymbol] + 1;
						totalFrequencyCounter <= totalFrequencyCounter + 1;
						
						for (int i = 0; i < DECODER_NUM_OF_SYMBOLS; ++i) begin
							if (i > currentSymbol) begin        // symbols lower than current symbol don't need any changes
								freqBegin[i] <= freqBegin[i] + 1;
								freqEnd[i] <= freqEnd[i] + 1;
							end
						end

                        unique case (outCurrentByte) inside     // perform interval rescaling

                            0: begin
                                out[7:0] <= currentSymbol;
                                currentState <= RESCALE;
                                outCurrentByte <= 1;
                            end

                            1: begin
                                out[15:8] <= currentSymbol;
                                currentState <= RESCALE;
                                outCurrentByte <= 2;
                            end

                            2: begin
                                out[23:16] <= currentSymbol;
                                currentState <= RESCALE;
                                outCurrentByte <= 3;
                            end

                            3: begin
                                out[31:24] <= currentSymbol;
                                currentState <= WAIT_FOR_READ_ACK;
                                nextState <= RESCALE;
                                resultReady <= 1;
                                outCurrentByte <= 0;
                            end

                        endcase

					end

				end
				else begin      // last symbol

                    validOutputBytes <= outCurrentByte;
				
				    if (outCurrentByte != 0) begin      // emit remaining bits, then finish decoder operation
                        currentState <= WAIT_FOR_READ_ACK;
                        nextState <= IDLE;
                        resultReady <= 1;
					end
					else begin                          // no bits left to be emitted, finish decoder operation
					    currentState <= IDLE;
					end
					
				end

            end

			RESCALE: begin

                if ( (b < half) || (a > half) || ((a > quarter) && (b < threeQuarters)) ) begin
					
					if (b < half) begin         // expand left half of the interval [a = 2a, b = 2b]
                        a <= (a << 1);
                        b <= (b << 1);
                        z <= ((z << 1) | inputBits[zCurrentBit]);                  // update 'z' approximation
					end
					else if (a > half) begin    // expand right half of the interval [a = 2(a-HALF), b = 2(b-HALF)]
                        a <= ((a-half) << 1);
                        b <= ((b-half) << 1);
                        z <= (((z-half) << 1) | inputBits[zCurrentBit]);           // update 'z' approximation
					end
					else begin                  // expand middle of the current interval [a = 2(a-QUARTER), b = 2(b-QUARTER)]
                        a <= ((a-quarter) << 1);
                        b <= ((b-quarter) << 1);
                        z <= (((z-quarter) << 1) | inputBits[zCurrentBit]);        // update 'z' approximation
					end
					
					if (zCurrentBit != 31) begin
						zCurrentBit <= zCurrentBit + 1;
					end
					else begin
						newBitsRequested <= 1;
						currentState <= WAIT_FOR_NEW_BITS;
						nextState <= RESCALE;
					end
					
				end

				else begin      // end scaling [one of the interval quarters is contained in the [a, b) interval]
					w <= (b - a);                           // adjust the subinterval width
					currentSymbol <= 0;                     // reset the current symbol
					currentState <= NEW_SUBINTERVAL_1;      // start decoding the next symbol
				end

			end

            HALVE_FREQUENCIES_1: begin

                for (int i = 0; i < DECODER_NUM_OF_SYMBOLS; ++i) begin

                    if (frequencyCounter[i] != 1) begin     // halve all the frequencies, but don't change them if they are 1, to avoid deleting intervals
                        frequencyCounter[i] <= (frequencyCounter[i] >> 1);
                    end

                end

                currentState <= HALVE_FREQUENCIES_2;

            end

            HALVE_FREQUENCIES_2: begin      // iterate through all the symbols and apply the halved frequencies to their corresponding model registers

                if (halveFrequenciesSymbolIndex != DECODER_NUM_OF_SYMBOLS) begin

                    freqBegin[halveFrequenciesSymbolIndex] <= halveFrequenciesHelperCounter;
                    freqEnd[halveFrequenciesSymbolIndex] <= halveFrequenciesHelperCounter + frequencyCounter[halveFrequenciesSymbolIndex];
                    totalFrequencyCounter <= totalFrequencyCounter + frequencyCounter[halveFrequenciesSymbolIndex];
                    halveFrequenciesHelperCounter <= halveFrequenciesHelperCounter + frequencyCounter[halveFrequenciesSymbolIndex];
                    halveFrequenciesSymbolIndex <= halveFrequenciesSymbolIndex + 1;

                end

                else begin

                    currentState <= FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL;       // halving frequencies done, go back to model updating state

                end

            end

            WAIT_FOR_READ_ACK: begin

                if (readSuccess) begin          // read ACK input set - finish waiting
                
                    resultReady <= 0;
                    currentState <= READ_ACKNOWLEDGED;
                    out <= 0;
            
                end

            end

            READ_ACKNOWLEDGED: begin

                if (!readSuccess) begin         // wait for read ACK input to be cleared before continuing operation

                    currentState <= nextState;

                end

            end

            WAIT_FOR_NEW_BITS: begin

				if (newBitsProvided) begin      // input indicating new bits provided set - finish waiting

					newBitsRequested <= 0;
					zCurrentBit <= 0;           // reset currently handled input bit
					currentState <= NEW_BITS_PROVIDED;

				end

			end

			NEW_BITS_PROVIDED: begin

				if (!newBitsProvided) begin     // wait for input indicating new bits provided to be cleared before continuing operation

					currentState <= nextState;

				end

			end

            default: begin

            end

        endcase

    end

end

endmodule
