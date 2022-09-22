// main parameters of the codec
parameter PRECISION = 32;
parameter NUM_OF_SYMBOLS = 257;
parameter EOF_SYMBOL = 256;

// helper parameters
parameter LOG2_OF_NUM_OF_SYMBOLS = $clog2(NUM_OF_SYMBOLS);
parameter INITIAL_TOTALFREQUENCYCOUNTER_VALUE = 100001;

module arithmetic_codec (
    input uwire clk,
	input uwire rstn,
    input logic start,
    input logic readSuccess,
    input logic newBitsProvided,
    input logic encodeDecodeSwitch,
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
logic [PRECISION-3:0] divisor_tdata;
logic dividend_tvalid;
logic dividend_tready;
logic [(PRECISION*2)-3:0] dividend_tdata;
logic dout_tvalid;
logic [(PRECISION*2)-3:0] dout_tdata;

divider divider_inst (clk, rstn, divisor_tvalid, divisor_tready, divisor_tdata, dividend_tvalid, 
                      dividend_tready, dividend_tdata, dout_tvalid, dout_tdata);

// values determining interval width
logic [PRECISION-1:0] whole;
logic [PRECISION-2:0] threeQuarters;
logic [PRECISION-2:0] half;
logic [PRECISION-3:0] quarter;

// values determining subinterval
logic [PRECISION-2:0] a;
logic [2*(PRECISION-2):0] aTemp;
logic [PRECISION-1:0] b;
logic [2*(PRECISION-1):0] bTemp;
logic [PRECISION-1:0] w;

// helper register for encoder "middle" case
logic [6:0] s;

// finite state machine of the codec
enum logic [3:0] {
				IDLE = 0,
				NEW_SUBINTERVAL_1 = 1,
                NEW_SUBINTERVAL_2 = 2,
                NEW_SUBINTERVAL_3 = 3,
                NEW_SUBINTERVAL_4 = 4,
                FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL = 5,
                ENCODER_DETERMINE_SUBINTERVAL_CASE = 6,
                ENCODER_EMIT_REMAINING_BITS = 7,
                DECODER_CHECK_IF_SYMBOL_FOUND = 8,
				DECODER_RESCALE = 9,
                WAIT_FOR_READ_ACK = 10,
				READ_ACKNOWLEDGED = 11,
                WAIT_FOR_NEW_BITS = 12,
				NEW_BITS_PROVIDED = 13
				} 
currentState, nextState;

// register for decoder input bits
logic [PRECISION-2:0] z;

// helper registers used in determining current bits/bytes for operations
logic [4:0] zCurrentBit;
logic [4:0] outCurrentBit;
logic [1:0] outCurrentByte;

// flags
logic zerosOrOnes;
logic lastSymbol;

// register storing current symbol
logic [LOG2_OF_NUM_OF_SYMBOLS-1:0] currentSymbol;

// probabilistic model
logic [PRECISION-4:0] initialFreqBegin [0:NUM_OF_SYMBOLS-1] = {
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
1609,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
4749,
6262,
7814,
9372,
10930,
12402,
14070,
15645,
17257,
18821,
18821,
18821,
18821,
18821,
18821,
18821,
18821,
20370,
21951,
23435,
24984,
26465,
28034,
29604,
31149,
32721,
34268,
35773,
37386,
38938,
40454,
41953,
43525,
45125,
46669,
48242,
49828,
51374,
52933,
54494,
56064,
57651,
59231,
59231,
59231,
59231,
59231,
59231,
59231,
60717,
62350,
63897,
65422,
66951,
68476,
70031,
71610,
73202,
74714,
76254,
77809,
79419,
81015,
82609,
84276,
85847,
87500,
89127,
90700,
92246,
93846,
95360,
96882,
98436,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000
};

logic [PRECISION-4:0] initialFreqEnd [0:NUM_OF_SYMBOLS-1] = {
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
0,
1609,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
3203,
4749,
6262,
7814,
9372,
10930,
12402,
14070,
15645,
17257,
18821,
18821,
18821,
18821,
18821,
18821,
18821,
18821,
20370,
21951,
23435,
24984,
26465,
28034,
29604,
31149,
32721,
34268,
35773,
37386,
38938,
40454,
41953,
43525,
45125,
46669,
48242,
49828,
51374,
52933,
54494,
56064,
57651,
59231,
59231,
59231,
59231,
59231,
59231,
59231,
60717,
62350,
63897,
65422,
66951,
68476,
70031,
71610,
73202,
74714,
76254,
77809,
79419,
81015,
82609,
84276,
85847,
87500,
89127,
90700,
92246,
93846,
95360,
96882,
98436,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100000,
100001
};

logic [PRECISION-4:0] freqBegin [0:NUM_OF_SYMBOLS-1];
logic [PRECISION-4:0] freqEnd [0:NUM_OF_SYMBOLS-1];
logic [PRECISION-4:0] totalFrequencyCounter;

always_ff @ (posedge clk) begin

	if (!rstn) begin

        // initialize interval values according to set precision
        whole <= (1 << (PRECISION-1));
        threeQuarters <= (3 << (PRECISION-3));
        half <= (1 << (PRECISION-2));
        quarter <= (1 << (PRECISION-3));
		
        // initialize FSM
		currentState <= IDLE;
        
        // initialize codec outputs
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
                s <= 0;

                outCurrentBit <= 0;
                outCurrentByte <= 0;
                zCurrentBit <= PRECISION-1;

                lastSymbol <= 0;
                idle <= 1;
                validOutputBytes <= 4;

                // set all symbols' frequencies to their initial values
                for (int i = 0; i < NUM_OF_SYMBOLS; ++i) begin
                    freqBegin[i] <= initialFreqBegin[i];
                    freqEnd[i] <= initialFreqEnd[i];
                end
                totalFrequencyCounter <= INITIAL_TOTALFREQUENCYCOUNTER_VALUE;

                if (start == 1) begin       // 'start' input triggered - start the operation of codec
                    
                    currentState <= NEW_SUBINTERVAL_1;
                    idle <= 0;

                    if (!encodeDecodeSwitch) begin      // encoder - take first symbol to encode
                        currentSymbol <= inputBits;     
                    end
                    else begin      // decoder - initialize as many 'z' bits as precision allows
                        currentSymbol <= 0;
                        for (int i = 0; i <= PRECISION-2; ++i) begin
                            z[PRECISION-2-i] <= inputBits[i];
                        end
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

                    b <= a + dout_tdata;        // set new subinterval end value using divider output

                    if (!encodeDecodeSwitch) begin      // encoder - start second division operation (subinterval start)
                        dividend_tdata <= aTemp;
                        dividend_tvalid <= 1;
                        divisor_tvalid <= 1;
                        currentState <= NEW_SUBINTERVAL_4;
                    end
                    else begin      // decoder - check if calculated subinterval end is greater than 'z'
                        currentState <= DECODER_CHECK_IF_SYMBOL_FOUND;
                    end

                end

            end

            NEW_SUBINTERVAL_4: begin

                // clear inputs' "valid" AXI-Stream signals
				dividend_tvalid <= 0;
                divisor_tvalid <= 0;

                // wait for output's "valid" AXI-Stream signal indicating completion of the division operation
                if (dout_tvalid) begin

                    a <= a + dout_tdata;        // set new subinterval start value using divider output
                    
                    if (!encodeDecodeSwitch) begin
                        currentState <= ENCODER_DETERMINE_SUBINTERVAL_CASE;
                    end
                    else begin
                        currentState <= FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL;
                    end

                end

			end

            FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL: begin

                if (currentSymbol != EOF_SYMBOL) begin

                    // update probabilistic model
                    freqEnd[currentSymbol] <= freqEnd[currentSymbol] - 1;
                    totalFrequencyCounter <= totalFrequencyCounter - 1;
                    
                    for (int i = 0; i < NUM_OF_SYMBOLS; ++i) begin
                        if (i > currentSymbol) begin    // symbols lower than current symbol don't need any changes
                            freqBegin[i] <= freqBegin[i] - 1;
                            freqEnd[i] <= freqEnd[i] - 1;
                        end
                    end

                    if (!encodeDecodeSwitch) begin              // encoder - not last symbol

                        currentSymbol <= inputBits;             // take new symbol from the input
                        w <= (b - a);                           // adjust current interval width
                        currentState <= NEW_SUBINTERVAL_1;      // start encoding the next symbol

                    end

                    else begin

                        unique case (outCurrentByte) inside     // decoder - perform interval rescaling

                            0: begin
                                out[7:0] <= currentSymbol;
                                currentState <= DECODER_RESCALE;
                                outCurrentByte <= 1;
                            end

                            1: begin
                                out[15:8] <= currentSymbol;
                                currentState <= DECODER_RESCALE;
                                outCurrentByte <= 2;
                            end

                            2: begin
                                out[23:16] <= currentSymbol;
                                currentState <= DECODER_RESCALE;
                                outCurrentByte <= 3;
                            end

                            3: begin
                                out[31:24] <= currentSymbol;
                                currentState <= WAIT_FOR_READ_ACK;
                                nextState <= DECODER_RESCALE;
                                resultReady <= 1;
                                outCurrentByte <= 0;
                            end

                        endcase

                    end


				end
				else begin      // last symbol

                    if (!encodeDecodeSwitch) begin

                        lastSymbol <= 1;
                        s <= s + 1;

                        if (a <= quarter) begin     // [1/4; 1/2) interval used - emit 0, then 's' ones
                            out[outCurrentBit] <= 0;
                            zerosOrOnes <= 1;
                        end
                        else begin                  // [1/2; 3/4] interval used - emit 1, then 's' zeros
                            out[outCurrentBit] <= 1;
                            zerosOrOnes <= 0;
                        end

                        if (outCurrentBit != 31) begin
                            outCurrentBit <= outCurrentBit + 1;
                            currentState <= ENCODER_EMIT_REMAINING_BITS;
                        end
                        else begin
                            nextState <= ENCODER_EMIT_REMAINING_BITS;
                            resultReady <= 1;
                            currentState <= WAIT_FOR_READ_ACK;
                        end

                    end
                    else begin

                        validOutputBytes <= outCurrentByte;
				
                        if (outCurrentByte != 0) begin      // emit remaining bits, then finish decoder operation
                            currentState <= WAIT_FOR_READ_ACK;
                            nextState <= IDLE;
                            resultReady <= 1;
                        end
                        
                        else begin      // no bits left to be emitted, finish decoder operation
                            currentState <= IDLE;
                        end

                    end
					
				end

            end

            ENCODER_DETERMINE_SUBINTERVAL_CASE: begin

                if ((a > half) || (b < half)) begin

                    if (b < half) begin     // expand left half of the interval [a = 2a, b = 2b]

                        out[outCurrentBit] <= 0;
                        zerosOrOnes <= 1;

                        a <= (a << 1);
                        b <= (b << 1);

                    end

                    else begin              // expand right half of the interval [a = 2(a-HALF), b = 2(b-HALF)]

                        out[outCurrentBit] <= 1;
                        zerosOrOnes <= 0;

                        a <= ((a - half) << 1);
                        b <= ((b - half) << 1);

                    end


                    if (outCurrentBit != 31) begin      // not all output bits filled yet - continue encoder operation

                        outCurrentBit <= outCurrentBit + 1;

                        if (s != 0) begin
                            currentState <= ENCODER_EMIT_REMAINING_BITS;
                        end

                    end

                    else begin              // all output bits filled - stop the encoder until they are read

                        if (s != 0) begin
                            nextState <= ENCODER_EMIT_REMAINING_BITS;
                        end
                        else begin
                            nextState <= ENCODER_DETERMINE_SUBINTERVAL_CASE;
                        end

                        resultReady <= 1;
                        currentState <= WAIT_FOR_READ_ACK;

                    end

                end

                else if ((a > quarter) && (b < threeQuarters)) begin        // expand middle of the current interval [a = 2(a-QUARTER), b = 2(b-QUARTER)]

                    a <= ((a - quarter) << 1);
                    b <= ((b - quarter) << 1);
                    s <= (s + 1);

                end

                else begin                  // end scaling [one of the interval quarters is contained in the [a, b) interval]

                    if (currentSymbol == EOF_SYMBOL) begin
                        currentState <= FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL;
                    end
                    else begin
                        currentState <= WAIT_FOR_NEW_BITS;
                        nextState <= FINISH_HANDLING_SYMBOL_AND_UPDATE_MODEL;
                        newBitsRequested <= 1;
                    end

                end

            end

            ENCODER_EMIT_REMAINING_BITS: begin     // emit 0 or 1 bits 's' times

                out[outCurrentBit] <= zerosOrOnes;

                s <= (s-1);

                if (outCurrentBit != 31) begin      // not all output bits filled yet - continue encoder operation

                    outCurrentBit <= outCurrentBit + 1;

                    if (s == 1) begin       // last bit is being emitted

                        if (!lastSymbol) begin
                            currentState <= ENCODER_DETERMINE_SUBINTERVAL_CASE;
                        end
                        else begin      // encoder operation finished - indicate which bytes of the output are valid data

                            if (outCurrentBit < 8) begin
                                validOutputBytes <= 1;
                            end
                            else if (outCurrentBit < 16) begin
                                validOutputBytes <= 2;
                            end
                            else if (outCurrentBit < 24) begin
                                validOutputBytes <= 3;
                            end

                            nextState <= IDLE;
                            resultReady <= 1;
                            currentState <= WAIT_FOR_READ_ACK;
                        end

                    end

                end

                else begin      // all output bits filled - stop the encoder until they are read

                    if (s == 1) begin       // last bit is being emitted

                        if (!lastSymbol) begin
                            nextState <= ENCODER_DETERMINE_SUBINTERVAL_CASE;
                        end
                        else begin
                            nextState <= IDLE;
                        end

                    end
                    else begin
                        nextState <= ENCODER_EMIT_REMAINING_BITS;
                    end

                    resultReady <= 1;
                    currentState <= WAIT_FOR_READ_ACK;

                end

            end

            DECODER_CHECK_IF_SYMBOL_FOUND: begin

				if (b > z) begin    // symbol found - emit decoded symbol
                    currentState <= NEW_SUBINTERVAL_4;
                    dividend_tdata <= aTemp;
                    dividend_tvalid <= 1;
                    divisor_tvalid <= 1;
				end

				else begin          // wrong symbol - try with the next one
					currentState <= NEW_SUBINTERVAL_1;
					currentSymbol <= currentSymbol + 1;
				end

			end

			DECODER_RESCALE: begin

                if ( (b < half) || (a > half) || ((a > quarter) && (b < threeQuarters)) ) begin
					
					if (b < half) begin         // expand left half of the interval [a = 2a, b = 2b]
                        a <= (a << 1);
                        b <= (b << 1);
                        z <= ((z << 1) | inputBits[zCurrentBit]);           // update 'z' approximation
					end
					else if (a > half) begin    // expand right half of the interval [a = 2(a-HALF), b = 2(b-HALF)]
                        a <= ((a-half) << 1);
                        b <= ((b-half) << 1);
                        z <= (((z-half) << 1) | inputBits[zCurrentBit]);    // update 'z' approximation
					end
					else begin                  // expand middle of the current interval [a = 2(a-QUARTER), b = 2(b-QUARTER)]
                        a <= ((a-quarter) << 1);
                        b <= ((b-quarter) << 1);
                        z <= (((z-quarter) << 1) | inputBits[zCurrentBit]); // update 'z' approximation
					end
					
					if (zCurrentBit != 31) begin
						zCurrentBit <= zCurrentBit + 1;
					end
					else begin
						newBitsRequested <= 1;
						currentState <= WAIT_FOR_NEW_BITS;
						nextState <= DECODER_RESCALE;
					end
					
				end

				else begin      // end scaling [one of the interval quarters is contained in the [a, b) interval]
					w <= (b - a);                           // adjust the subinterval width
					currentSymbol <= 0;                     // reset the current symbol
					currentState <= NEW_SUBINTERVAL_1;      // start decoding the next symbol
				end

			end

            WAIT_FOR_READ_ACK: begin

                if (readSuccess) begin      // read ACK input set - finish waiting 
                
                    resultReady <= 0;
                    currentState <= READ_ACKNOWLEDGED;
                    out <= 0;
                    outCurrentBit <= 0;         // reset currently handled output bit
            
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
