// main parameters of the codec
parameter ENCODER_PRECISION = 16;
parameter ENCODER_NUM_OF_SYMBOLS = 257;
parameter ENCODER_EOF_SYMBOL = 256;

// helper parameter
parameter LOG2_OF_ENCODER_NUM_OF_SYMBOLS = $clog2(ENCODER_NUM_OF_SYMBOLS);

module arithmetic_encoder (
    input uwire clk,
	input uwire rstn,
    input logic start,
    input logic readSuccess,
    input logic newBitsProvided,
	input logic [31:0] inputBits,
	output logic idle,
    output logic resultReady,
    output logic newBitsRequested,
    output logic [1:0] lastValidByte,
    output logic [31:0] out
);

// divider IP
logic divisor_tvalid;
logic divisor_tready;
logic [ENCODER_PRECISION-3:0] divisor_tdata;
logic dividend_tvalid;
logic dividend_tready;
logic [(ENCODER_PRECISION*2)-3:0] dividend_tdata;
logic dout_tvalid;
logic [(ENCODER_PRECISION*2)-3:0] dout_tdata;

divider divider_inst (clk, rstn, divisor_tvalid, divisor_tready, divisor_tdata, dividend_tvalid, 
                      dividend_tready, dividend_tdata, dout_tvalid, dout_tdata);

// values determining interval width
logic [ENCODER_PRECISION-1:0] whole;
logic [ENCODER_PRECISION-2:0] threeQuarters;
logic [ENCODER_PRECISION-2:0] half;
logic [ENCODER_PRECISION-3:0] quarter;

// values determining subinterval
logic [ENCODER_PRECISION-2:0] a;
logic [2*(ENCODER_PRECISION-2):0] aTemp;
logic [ENCODER_PRECISION-1:0] b;
logic [2*(ENCODER_PRECISION-1):0] bTemp;
logic [ENCODER_PRECISION-1:0] w;

// helper register for encoder "middle" case
logic [6:0] s;

// finite state machine of the encoder
enum logic [3:0] {
				IDLE = 0,
				NEW_SUBINTERVAL_1 = 1,
                NEW_SUBINTERVAL_2 = 2,
                NEW_SUBINTERVAL_3 = 3,
                NEW_SUBINTERVAL_4 = 4,
				DETERMINE_SUBINTERVAL_CASE = 5,
				EMIT_REMAINING_BITS = 6,
				FINISH_HANDLING_SYMBOL = 7,
                WAIT_FOR_READ_ACK = 8,
				READ_ACKNOWLEDGED = 9,
                WAIT_FOR_NEW_BITS = 10,
				NEW_BITS_PROVIDED = 11
				} 
currentState, nextState;

// helper register used in determining currently handled bit
logic [4:0] outCurrentBit;

// flags
logic zerosOrOnes;
logic lastSymbol;

// register storing current symbol
logic [LOG2_OF_ENCODER_NUM_OF_SYMBOLS-1:0] currentSymbol;

// probabilistic model
logic [ENCODER_PRECISION-4:0] freqBegin [0:ENCODER_NUM_OF_SYMBOLS-1] = {
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

logic [ENCODER_PRECISION-4:0] freqEnd [0:ENCODER_NUM_OF_SYMBOLS-1] = {
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

logic [ENCODER_PRECISION-4:0] totalFrequencyCounter = 257;


always_ff @ (posedge clk) begin

	if (!rstn) begin

        // initialize interval values according to set precision
        whole <= (1 << (ENCODER_PRECISION-1));
        threeQuarters <= (3 << (ENCODER_PRECISION-3));
        half <= (1 << (ENCODER_PRECISION-2));
        quarter <= (1 << (ENCODER_PRECISION-3));
		
        // initialize FSM
		currentState <= IDLE;
        
        // initialize encoder outputs
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

                lastSymbol <= 0;
                idle <= 1;
                lastValidByte <= 3;

                if (start == 1) begin         // 'start' input triggered - start the operation of encoder
                    
                    currentState <= NEW_SUBINTERVAL_1;
                    idle <= 0;
                    currentSymbol <= inputBits;     // take first symbol to encode
                    
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

                    b <= a + dout_tdata;            // set new subinterval end value using divider output
                    dividend_tdata <= aTemp;        // start second division operation (subinterval start)
                    dividend_tvalid <= 1;
                    divisor_tvalid <= 1;
                    currentState <= NEW_SUBINTERVAL_4;

                end

            end

            NEW_SUBINTERVAL_4: begin

                // clear inputs' "valid" AXI-Stream signals
				dividend_tvalid <= 0;
                divisor_tvalid <= 0;

                // wait for output's "valid" AXI-Stream signal indicating completion of the division operation
                if (dout_tvalid) begin

                    a <= a + dout_tdata;        // set new subinterval start value using divider output
                    currentState <= DETERMINE_SUBINTERVAL_CASE;

                end

			end

            DETERMINE_SUBINTERVAL_CASE: begin

                if ((a > half) || (b < half)) begin

                    if (b < half) begin          // expand left half of the interval [a = 2a, b = 2b]

                        out[outCurrentBit] <= 0;
                        zerosOrOnes <= 1;

                        a <= (a << 1);
                        b <= (b << 1);

                    end

                    else begin                   // expand right half of the interval [a = 2(a-HALF), b = 2(b-HALF)]

                        out[outCurrentBit] <= 1;
                        zerosOrOnes <= 0;

                        a <= ((a - half) << 1);
                        b <= ((b - half) << 1);

                    end

                    if (outCurrentBit != 31) begin      // not all output bits filled yet - continue encoder operation

                        outCurrentBit <= outCurrentBit + 1;

                        if (s != 0) begin
                            currentState <= EMIT_REMAINING_BITS;
                        end

                    end

                    else begin              // all output bits filled - stop the encoder until they are read

                        if (s != 0) begin
                            nextState <= EMIT_REMAINING_BITS;
                        end
                        else begin
                            nextState <= DETERMINE_SUBINTERVAL_CASE;
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

                    if (currentSymbol == ENCODER_EOF_SYMBOL) begin
                        currentState <= FINISH_HANDLING_SYMBOL;
                    end
                    else begin
                        currentState <= WAIT_FOR_NEW_BITS;
                        nextState <= FINISH_HANDLING_SYMBOL;
                        newBitsRequested <= 1;
                    end

                end

            end

            EMIT_REMAINING_BITS: begin     // emit 0 or 1 bits 's' times

                out[outCurrentBit] <= zerosOrOnes;

                s <= (s-1);

                if (outCurrentBit != 31) begin      // not all output bits filled yet - continue encoder operation

                    outCurrentBit <= outCurrentBit + 1;

                    if (s == 1) begin               // last bit is being emitted

                        if (!lastSymbol) begin
                            currentState <= DETERMINE_SUBINTERVAL_CASE;
                        end
                        else begin                  // encoder operation finished - indicate which bytes of the output are valid data

                            if (outCurrentBit < 8) begin
                                lastValidByte <= 0;
                            end
                            else if (outCurrentBit < 16) begin
                                lastValidByte <= 1;
                            end
                            else if (outCurrentBit < 24) begin
                                lastValidByte <= 2;
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
                            nextState <= DETERMINE_SUBINTERVAL_CASE;
                        end
                        else begin
                            nextState <= IDLE;
                        end

                    end
                    else begin
                        nextState <= EMIT_REMAINING_BITS;
                    end

                    resultReady <= 1;
                    currentState <= WAIT_FOR_READ_ACK;

                end

            end

            FINISH_HANDLING_SYMBOL: begin

                if (currentSymbol != ENCODER_EOF_SYMBOL) begin

                    currentSymbol <= inputBits;                     // take new symbol from the input
                    w <= (b - a);                                   // adjust current interval width
                    currentState <= NEW_SUBINTERVAL_1;              // start encoding the next symbol

                end
                else begin      // last symbol

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
                        currentState <= EMIT_REMAINING_BITS;
                    end
                    else begin
                        nextState <= EMIT_REMAINING_BITS;
                        resultReady <= 1;
                        currentState <= WAIT_FOR_READ_ACK;
                    end

                end

            end

            WAIT_FOR_READ_ACK: begin

                if (readSuccess) begin          // read ACK input set - finish waiting 
                
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
