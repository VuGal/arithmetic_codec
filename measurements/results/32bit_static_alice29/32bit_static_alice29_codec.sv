// main parameters of the codec
parameter PRECISION = 32;
parameter NUM_OF_SYMBOLS = 257;
parameter EOF_SYMBOL = 256;

// helper parameter
parameter LOG2_OF_NUM_OF_SYMBOLS = $clog2(NUM_OF_SYMBOLS);

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
                FINISH_HANDLING_SYMBOL = 5,
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
logic [PRECISION-4:0] freqBegin [0:NUM_OF_SYMBOLS-1] = {
0,
1,
2,
3,
4,
5,
6,
7,
8,
9,
10,
12736085,
12736086,
12736087,
25472162,
25472163,
25472164,
25472165,
25472166,
25472167,
25472168,
25472169,
25472170,
25472171,
25472172,
25472173,
25472174,
25475704,
25475705,
25475706,
25475707,
25475708,
25475709,
127491384,
129076333,
129475218,
129475219,
129475220,
129475221,
129475222,
135691471,
135889148,
136083295,
136295092,
136295093,
144830522,
147192061,
150640826,
150640827,
150640828,
150640829,
150644359,
150644360,
150644361,
150644362,
150644363,
150644364,
150644365,
150647895,
151470374,
152155185,
152155186,
152155187,
152155188,
152868239,
152868240,
155120351,
155441577,
155949890,
156627641,
157291272,
157552489,
157841945,
158844452,
161431908,
161460148,
161749604,
162095540,
162801531,
163225125,
163846397,
164072314,
164368830,
164863024,
165632554,
167298692,
167531669,
167679927,
168516526,
168530646,
168933061,
168936591,
168943651,
168943652,
168950712,
168950713,
168964833,
172876022,
201641618,
206523545,
214476532,
231204985,
278439302,
285237994,
293872262,
318892577,
342818606,
343305740,
347103971,
363394709,
370126332,
394458306,
422574391,
427721064,
428162308,
446846355,
469003877,
505051769,
517060673,
519895226,
528497724,
529006037,
536595438,
536867244,
536867245,
536867246,
536867247,
536867248,
536867249,
536867250,
536867251,
536867252,
536867253,
536867254,
536867255,
536867256,
536867257,
536867258,
536867259,
536867260,
536867261,
536867262,
536867263,
536867264,
536867265,
536867266,
536867267,
536867268,
536867269,
536867270,
536867271,
536867272,
536867273,
536867274,
536867275,
536867276,
536867277,
536867278,
536867279,
536867280,
536867281,
536867282,
536867283,
536867284,
536867285,
536867286,
536867287,
536867288,
536867289,
536867290,
536867291,
536867292,
536867293,
536867294,
536867295,
536867296,
536867297,
536867298,
536867299,
536867300,
536867301,
536867302,
536867303,
536867304,
536867305,
536867306,
536867307,
536867308,
536867309,
536867310,
536867311,
536867312,
536867313,
536867314,
536867315,
536867316,
536867317,
536867318,
536867319,
536867320,
536867321,
536867322,
536867323,
536867324,
536867325,
536867326,
536867327,
536867328,
536867329,
536867330,
536867331,
536867332,
536867333,
536867334,
536867335,
536867336,
536867337,
536867338,
536867339,
536867340,
536867341,
536867342,
536867343,
536867344,
536867345,
536867346,
536867347,
536867348,
536867349,
536867350,
536867351,
536867352,
536867353,
536867354,
536867355,
536867356,
536867357,
536867358,
536867359,
536867360,
536867361,
536867362,
536867363,
536867364,
536867365,
536867366,
536867367,
536867368,
536867369,
536867370,
536867371,
536867372,
536867373,
536867374,
536867375,
536867376,
536867377
};

logic [PRECISION-4:0] freqEnd [0:NUM_OF_SYMBOLS-1] = {
1,
2,
3,
4,
5,
6,
7,
8,
9,
10,
12736085,
12736086,
12736087,
25472162,
25472163,
25472164,
25472165,
25472166,
25472167,
25472168,
25472169,
25472170,
25472171,
25472172,
25472173,
25472174,
25475704,
25475705,
25475706,
25475707,
25475708,
25475709,
127491384,
129076333,
129475218,
129475219,
129475220,
129475221,
129475222,
135691471,
135889148,
136083295,
136295092,
136295093,
144830522,
147192061,
150640826,
150640827,
150640828,
150640829,
150644359,
150644360,
150644361,
150644362,
150644363,
150644364,
150644365,
150647895,
151470374,
152155185,
152155186,
152155187,
152155188,
152868239,
152868240,
155120351,
155441577,
155949890,
156627641,
157291272,
157552489,
157841945,
158844452,
161431908,
161460148,
161749604,
162095540,
162801531,
163225125,
163846397,
164072314,
164368830,
164863024,
165632554,
167298692,
167531669,
167679927,
168516526,
168530646,
168933061,
168936591,
168943651,
168943652,
168950712,
168950713,
168964833,
172876022,
201641618,
206523545,
214476532,
231204985,
278439302,
285237994,
293872262,
318892577,
342818606,
343305740,
347103971,
363394709,
370126332,
394458306,
422574391,
427721064,
428162308,
446846355,
469003877,
505051769,
517060673,
519895226,
528497724,
529006037,
536595438,
536867244,
536867245,
536867246,
536867247,
536867248,
536867249,
536867250,
536867251,
536867252,
536867253,
536867254,
536867255,
536867256,
536867257,
536867258,
536867259,
536867260,
536867261,
536867262,
536867263,
536867264,
536867265,
536867266,
536867267,
536867268,
536867269,
536867270,
536867271,
536867272,
536867273,
536867274,
536867275,
536867276,
536867277,
536867278,
536867279,
536867280,
536867281,
536867282,
536867283,
536867284,
536867285,
536867286,
536867287,
536867288,
536867289,
536867290,
536867291,
536867292,
536867293,
536867294,
536867295,
536867296,
536867297,
536867298,
536867299,
536867300,
536867301,
536867302,
536867303,
536867304,
536867305,
536867306,
536867307,
536867308,
536867309,
536867310,
536867311,
536867312,
536867313,
536867314,
536867315,
536867316,
536867317,
536867318,
536867319,
536867320,
536867321,
536867322,
536867323,
536867324,
536867325,
536867326,
536867327,
536867328,
536867329,
536867330,
536867331,
536867332,
536867333,
536867334,
536867335,
536867336,
536867337,
536867338,
536867339,
536867340,
536867341,
536867342,
536867343,
536867344,
536867345,
536867346,
536867347,
536867348,
536867349,
536867350,
536867351,
536867352,
536867353,
536867354,
536867355,
536867356,
536867357,
536867358,
536867359,
536867360,
536867361,
536867362,
536867363,
536867364,
536867365,
536867366,
536867367,
536867368,
536867369,
536867370,
536867371,
536867372,
536867373,
536867374,
536867375,
536867376,
536867377,
536870911
};

logic [PRECISION-4:0] totalFrequencyCounter = 536870911;

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
                        currentState <= FINISH_HANDLING_SYMBOL;
                    end

                end

			end

            FINISH_HANDLING_SYMBOL: begin

                if (currentSymbol != EOF_SYMBOL) begin

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
                        currentState <= FINISH_HANDLING_SYMBOL;
                    end
                    else begin
                        currentState <= WAIT_FOR_NEW_BITS;
                        nextState <= FINISH_HANDLING_SYMBOL;
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
