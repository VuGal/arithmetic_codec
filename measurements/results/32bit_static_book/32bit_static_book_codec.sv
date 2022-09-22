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
4,
8,
12,
16,
20,
24,
28,
32,
36,
40,
44,
48,
52,
56,
60,
64,
68,
72,
76,
80,
84,
88,
92,
96,
100,
104,
108,
112,
116,
120,
124,
128,
132,
557941,
562773,
1096423,
5869741,
5969599,
11558960,
12728264,
15154920,
17607882,
17682507,
18257496,
24439026,
26949970,
34967061,
35401926,
42173477,
49860929,
53395149,
55206551,
56815553,
58374089,
59738814,
60847989,
61917972,
63135058,
64463813,
64937870,
64999610,
65975641,
66061003,
66171062,
66457751,
67736577,
68343778,
69525431,
70046196,
70798352,
71541381,
71894105,
72513117,
73868716,
74127488,
74236473,
75165796,
75667233,
76094045,
76345301,
77290730,
77378777,
77887730,
79053813,
81377390,
81516976,
81679648,
82284701,
82426435,
82524145,
82783990,
83981212,
95909406,
97081395,
98417129,
99544021,
100527031,
131069071,
141070973,
157300039,
173191950,
226499457,
237785554,
245310334,
264542655,
297580070,
297896824,
300163492,
318055783,
330019411,
357769186,
387604704,
399479748,
400395649,
428057914,
459034282,
496823003,
507083140,
511058668,
516214238,
519478412,
524960399,
525851604,
530012352,
532709591,
536870339,
536870343,
536870347,
536870351,
536870355,
536870359,
536870363,
536870367,
536870371,
536870375,
536870379,
536870383,
536870387,
536870391,
536870395,
536870399,
536870403,
536870407,
536870411,
536870415,
536870419,
536870423,
536870427,
536870431,
536870435,
536870439,
536870443,
536870447,
536870451,
536870455,
536870459,
536870463,
536870467,
536870471,
536870475,
536870479,
536870483,
536870487,
536870491,
536870495,
536870499,
536870503,
536870507,
536870511,
536870515,
536870519,
536870523,
536870527,
536870531,
536870535,
536870539,
536870543,
536870547,
536870551,
536870555,
536870559,
536870563,
536870567,
536870571,
536870575,
536870579,
536870583,
536870587,
536870591,
536870595,
536870599,
536870603,
536870607,
536870611,
536870615,
536870619,
536870623,
536870627,
536870631,
536870635,
536870639,
536870643,
536870647,
536870651,
536870655,
536870659,
536870663,
536870667,
536870671,
536870675,
536870679,
536870683,
536870687,
536870691,
536870695,
536870699,
536870703,
536870707,
536870711,
536870715,
536870719,
536870723,
536870727,
536870731,
536870735,
536870739,
536870743,
536870747,
536870751,
536870755,
536870759,
536870763,
536870767,
536870771,
536870775,
536870779,
536870783,
536870787,
536870791,
536870795,
536870799,
536870803,
536870807,
536870811,
536870815,
536870819,
536870823,
536870827,
536870831,
536870835,
536870839,
536870843,
536870847,
536870851,
536870855,
536870859
};

logic [PRECISION-4:0] freqEnd [0:NUM_OF_SYMBOLS-1] = {
4,
8,
12,
16,
20,
24,
28,
32,
36,
40,
44,
48,
52,
56,
60,
64,
68,
72,
76,
80,
84,
88,
92,
96,
100,
104,
108,
112,
116,
120,
124,
128,
132,
557941,
562773,
1096423,
5869741,
5969599,
11558960,
12728264,
15154920,
17607882,
17682507,
18257496,
24439026,
26949970,
34967061,
35401926,
42173477,
49860929,
53395149,
55206551,
56815553,
58374089,
59738814,
60847989,
61917972,
63135058,
64463813,
64937870,
64999610,
65975641,
66061003,
66171062,
66457751,
67736577,
68343778,
69525431,
70046196,
70798352,
71541381,
71894105,
72513117,
73868716,
74127488,
74236473,
75165796,
75667233,
76094045,
76345301,
77290730,
77378777,
77887730,
79053813,
81377390,
81516976,
81679648,
82284701,
82426435,
82524145,
82783990,
83981212,
95909406,
97081395,
98417129,
99544021,
100527031,
131069071,
141070973,
157300039,
173191950,
226499457,
237785554,
245310334,
264542655,
297580070,
297896824,
300163492,
318055783,
330019411,
357769186,
387604704,
399479748,
400395649,
428057914,
459034282,
496823003,
507083140,
511058668,
516214238,
519478412,
524960399,
525851604,
530012352,
532709591,
536870339,
536870343,
536870347,
536870351,
536870355,
536870359,
536870363,
536870367,
536870371,
536870375,
536870379,
536870383,
536870387,
536870391,
536870395,
536870399,
536870403,
536870407,
536870411,
536870415,
536870419,
536870423,
536870427,
536870431,
536870435,
536870439,
536870443,
536870447,
536870451,
536870455,
536870459,
536870463,
536870467,
536870471,
536870475,
536870479,
536870483,
536870487,
536870491,
536870495,
536870499,
536870503,
536870507,
536870511,
536870515,
536870519,
536870523,
536870527,
536870531,
536870535,
536870539,
536870543,
536870547,
536870551,
536870555,
536870559,
536870563,
536870567,
536870571,
536870575,
536870579,
536870583,
536870587,
536870591,
536870595,
536870599,
536870603,
536870607,
536870611,
536870615,
536870619,
536870623,
536870627,
536870631,
536870635,
536870639,
536870643,
536870647,
536870651,
536870655,
536870659,
536870663,
536870667,
536870671,
536870675,
536870679,
536870683,
536870687,
536870691,
536870695,
536870699,
536870703,
536870707,
536870711,
536870715,
536870719,
536870723,
536870727,
536870731,
536870735,
536870739,
536870743,
536870747,
536870751,
536870755,
536870759,
536870763,
536870767,
536870771,
536870775,
536870779,
536870783,
536870787,
536870791,
536870795,
536870799,
536870803,
536870807,
536870811,
536870815,
536870819,
536870823,
536870827,
536870831,
536870835,
536870839,
536870843,
536870847,
536870851,
536870855,
536870859,
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
