// main parameters of the codec
parameter DECODER_PRECISION = 16;
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

// finite state machine of the decoder
enum logic [3:0] {
				IDLE = 0,
				NEW_SUBINTERVAL_1 = 1,
                NEW_SUBINTERVAL_2 = 2,
                NEW_SUBINTERVAL_3 = 3,
                CHECK_IF_SYMBOL_FOUND = 4,
                NEW_SUBINTERVAL_4 = 5,
				FINISH_HANDLING_SYMBOL = 6,
				RESCALE = 7,
                WAIT_FOR_READ_ACK = 8,
				READ_ACKNOWLEDGED = 9,
                WAIT_FOR_NEW_BITS = 10,
				NEW_BITS_PROVIDED = 11
				} 
currentState, nextState;

// register for decoder input bits
logic [DECODER_PRECISION-2:0] z;

// helper registers used in determining current bits/bytes for operations
logic [4:0] zCurrentBit;
logic [1:0] outCurrentByte;

// register storing current symbol
logic [LOG2_OF_DECODER_NUM_OF_SYMBOLS-1:0] currentSymbol;

// probabilistic model
logic [DECODER_PRECISION-4:0] freqBegin [0:DECODER_NUM_OF_SYMBOLS-1] = {
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
11,
12,
13,
14,
15,
16,
17,
18,
19,
20,
21,
22,
23,
24,
25,
26,
27,
28,
29,
30,
31,
32,
33,
34,
35,
36,
37,
38,
39,
40,
41,
42,
43,
44,
45,
46,
47,
48,
49,
50,
51,
52,
53,
54,
55,
56,
57,
58,
59,
60,
61,
62,
63,
64,
65,
66,
67,
68,
69,
70,
71,
72,
73,
74,
75,
76,
77,
78,
79,
80,
81,
82,
83,
84,
85,
86,
87,
88,
89,
90,
91,
92,
93,
94,
95,
96,
97,
98,
99,
100,
101,
102,
103,
104,
105,
106,
107,
108,
109,
110,
111,
112,
113,
114,
115,
116,
117,
118,
119,
120,
121,
122,
123,
124,
125,
126,
127,
128,
129,
130,
131,
132,
133,
134,
135,
136,
137,
138,
139,
140,
141,
142,
143,
144,
145,
146,
147,
148,
149,
150,
151,
152,
153,
154,
155,
156,
157,
158,
159,
160,
161,
162,
163,
164,
165,
166,
167,
168,
169,
170,
171,
172,
173,
174,
175,
176,
177,
178,
179,
180,
181,
182,
183,
184,
185,
186,
187,
188,
189,
190,
191,
192,
193,
194,
195,
196,
197,
198,
199,
200,
201,
202,
203,
204,
205,
206,
207,
208,
209,
210,
211,
212,
213,
214,
215,
216,
217,
218,
219,
220,
221,
222,
223,
224,
225,
226,
227,
228,
229,
230,
231,
232,
233,
234,
235,
236,
237,
238,
239,
240,
241,
242,
243,
244,
245,
246,
247,
248,
249,
250,
251,
252,
253,
254,
255,
256
};

logic [DECODER_PRECISION-4:0] freqEnd [0:DECODER_NUM_OF_SYMBOLS-1] = {
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
11,
12,
13,
14,
15,
16,
17,
18,
19,
20,
21,
22,
23,
24,
25,
26,
27,
28,
29,
30,
31,
32,
33,
34,
35,
36,
37,
38,
39,
40,
41,
42,
43,
44,
45,
46,
47,
48,
49,
50,
51,
52,
53,
54,
55,
56,
57,
58,
59,
60,
61,
62,
63,
64,
65,
66,
67,
68,
69,
70,
71,
72,
73,
74,
75,
76,
77,
78,
79,
80,
81,
82,
83,
84,
85,
86,
87,
88,
89,
90,
91,
92,
93,
94,
95,
96,
97,
98,
99,
100,
101,
102,
103,
104,
105,
106,
107,
108,
109,
110,
111,
112,
113,
114,
115,
116,
117,
118,
119,
120,
121,
122,
123,
124,
125,
126,
127,
128,
129,
130,
131,
132,
133,
134,
135,
136,
137,
138,
139,
140,
141,
142,
143,
144,
145,
146,
147,
148,
149,
150,
151,
152,
153,
154,
155,
156,
157,
158,
159,
160,
161,
162,
163,
164,
165,
166,
167,
168,
169,
170,
171,
172,
173,
174,
175,
176,
177,
178,
179,
180,
181,
182,
183,
184,
185,
186,
187,
188,
189,
190,
191,
192,
193,
194,
195,
196,
197,
198,
199,
200,
201,
202,
203,
204,
205,
206,
207,
208,
209,
210,
211,
212,
213,
214,
215,
216,
217,
218,
219,
220,
221,
222,
223,
224,
225,
226,
227,
228,
229,
230,
231,
232,
233,
234,
235,
236,
237,
238,
239,
240,
241,
242,
243,
244,
245,
246,
247,
248,
249,
250,
251,
252,
253,
254,
255,
256,
257
};

logic [DECODER_PRECISION-4:0] totalFrequencyCounter = 257;


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
                    currentState <= FINISH_HANDLING_SYMBOL;

                end

			end

            FINISH_HANDLING_SYMBOL: begin

                if (currentSymbol != DECODER_EOF_SYMBOL) begin

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
