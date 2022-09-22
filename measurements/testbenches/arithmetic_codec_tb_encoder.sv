`timescale 100fs/100fs

`define VERILOG_EOF_SYMBOL 32'hFFFFFFFF
`define CODEC_EOF_SYMBOL 256

`define INPUT_FILE_PATH "C:\\Users\\VuGal\\Desktop\\PRACA_MAGISTERSKA\\alice29.txt"
`define CODED_FILE_PATH "C:\\Users\\VuGal\\Desktop\\PRACA_MAGISTERSKA\\alice29_encoded.txt"


module arithmetic_codec_tb;

logic clk_port = 0;
logic rstn_port = 0;
logic start_port = 0;
logic readSuccess_port = 0;
logic newBitsProvided_port = 0;
logic encodeDecodeSwitch_port = 0;
logic [31:0] inputBits_port = 0;
logic idle_port;
logic resultReady_port;
logic newBitsRequested_port;
logic [2:0] validOutputBytes_port;
logic [31:0] out_port;

arithmetic_codec instance0 ( .clk(clk_port), 
                             .rstn(rstn_port),
                             .start(start_port),
                             .readSuccess(readSuccess_port),
                             .newBitsProvided(newBitsProvided_port),
                             .encodeDecodeSwitch(encodeDecodeSwitch_port),
                             .inputBits(inputBits_port),
                             .idle(idle_port),
                             .resultReady(resultReady_port),
                             .newBitsRequested(newBitsRequested_port),
                             .validOutputBytes(validOutputBytes_port),
                             .out(out_port) );
                             
int input_file;
int encoded_file;
int data_byte;

initial begin

    input_file = $fopen(`INPUT_FILE_PATH, "rb");
    if (input_file == 0) begin
        $display("input_file handle was NULL");
        $finish;
    end
    
    encoded_file = $fopen(`CODED_FILE_PATH, "wb");
    if (encoded_file == 0) begin
        $display("encoded_file handle was NULL");
        $finish;
    end

	rstn_port = 0;
    inputBits_port = $fgetc(input_file);
	#156250;
	rstn_port = 1;
	start_port = 1;
	#156250;
	start_port = 0;
	
	while (1) begin
	
        if (idle_port) begin
            break;
        end

	    if (!newBitsRequested_port && !resultReady_port) begin
			#156250;
		end

		if (newBitsRequested_port) begin
		
		    data_byte = $fgetc(input_file);

            if (data_byte != `VERILOG_EOF_SYMBOL) begin
                inputBits_port = data_byte;
            end
            else begin
                inputBits_port = `CODEC_EOF_SYMBOL;
            end
			
			newBitsProvided_port = 1;
			#156250;
			newBitsProvided_port = 0;
			
		end

		if (resultReady_port) begin
		
			readSuccess_port = 1;

            if (validOutputBytes_port >= 1) begin
                $fwrite(encoded_file, "%c", out_port[7:0]);
            end

            if (validOutputBytes_port >= 2) begin
                $fwrite(encoded_file, "%c", out_port[15:8]);
            end

            if (validOutputBytes_port >= 3) begin
                $fwrite(encoded_file, "%c", out_port[23:16]);
            end

            if (validOutputBytes_port >= 4) begin
                $fwrite(encoded_file, "%c", out_port[31:24]);
            end

			#156250;
			readSuccess_port = 0;
			
		end

	end
	
    $fclose(input_file);
    $fclose(encoded_file);
	$finish;
    
end    


always
	#78125 clk_port = ~clk_port;    // 64 MHz clock frequency

endmodule
