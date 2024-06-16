`timescale 1ns / 1ps

module circ_buf_tb(

    );
    
parameter COLOR_DEPTH = 8;
parameter CHANNELS = 3;
parameter TFRESX = 256;
parameter TFRESY = 256;
parameter ORIGRESX = 512;
parameter ORIGRESY = 512;
parameter ORIG_Y_SIZE = 9;
parameter ORIG_X_SIZE = 9;
    // Fixed point representation properties Q8.10 means 8 integer bits and 10 fractional bits. sign bit is not needed here
    parameter FRACT_BITS = 10;       // Fixed point number fractional part length
    parameter FIXED_POINT_BITS = 18;      // Fixed point number total length, should be 18
    parameter INT_BITS = FIXED_POINT_BITS - FRACT_BITS;        // Fixed poin number integer part length. The total bit length should sum up to 18
    parameter COEFF_BITS = FRACT_BITS + 1;   // The bilinear coefficients width, in the form of Q1.FRACT_BITS, since it is max. 1, the integer part does not need to be longer
    //---------------------------
    
reg clk = 1;
reg rst = 1;
reg start = 0; 
always #5
   clk <= ~clk;
   
initial
begin
   rst <= 1;
   #20 
   rst <= 0;
end
reg [CHANNELS*COLOR_DEPTH-1:0] output_array[TFRESX*TFRESY-1:0];    
reg [CHANNELS*COLOR_DEPTH-1:0] input_array[ORIGRESX*ORIGRESY-1:0];

integer file_in, file_out;
initial
begin
    file_in = $fopen("lena.raw", "rb");
    //file_out = $fopen("lena_out.raw", "wb");
    
    $fread(input_array, file_in);
    $fclose(file_in);
    //$fclose(file_out);
    //$stop;
end

wire [CHANNELS*COLOR_DEPTH-1:0] inPx;
wire [CHANNELS*COLOR_DEPTH-1:0] readData00;
wire [CHANNELS*COLOR_DEPTH-1:0] readData10;
wire [CHANNELS*COLOR_DEPTH-1:0] readData01;
wire [CHANNELS*COLOR_DEPTH-1:0] readData11;
assign inPx = input_array[requestRow*ORIGRESY + requestCol];
wire [ORIG_Y_SIZE-1:0]requestCol;
wire [ORIG_X_SIZE-1:0]requestRow;

reg doneProcessing=0;
reg [31:0] counter = 0;
wire readyForRead;
always @ (posedge clk) begin
    if (!rst) begin
        if (counter ==1500) begin
            doneProcessing<=1;
        end
        else if (counter <1500) begin
            counter = counter + 1;
        end
        if (readyForRead) begin
            counter <=0;
            doneProcessing<=0;
        end
    end
end



reg [FIXED_POINT_BITS-1:0] yScale = {14'b00001010001110};
circ_buf#(
	.DATA_WIDTH(COLOR_DEPTH*CHANNELS), // pixel depth
    .BUFFER_SIZE(2), // 2**BUFFER_SIZE lines are stored at maximum
    .ORIG_X_SIZE(ORIG_X_SIZE),    // Original image width 11 bit for 1080p 
    .ORIG_Y_SIZE(ORIG_Y_SIZE),    // Original image height
    .ORIGRESX(ORIGRESX),
    .ORIGRESY(ORIGRESY),
    .NUMROWSTOSTORE(2)
)uut(
	.clk(clk),
	.rst(rst),
	.start(start),

	.writeData(inPx),
	.writeDone(),
    
    .doneProcessing(doneProcessing),
    .readyForRead(readyForRead),
	.requestRow(requestRow),
	.requestCol(requestCol),
	.dInValid(1'b1),
	.yScale(yScale),
	.readData00(readData00),		//Read from deepest RAM (earliest data), at readAddress
	.readData01(readData01),		//Read from deepest RAM (earliest data), at readAddress + 1
	.readData10(readData10),		//Read from second deepest RAM (second earliest data), at readAddress
	.readData11(readData11),		//Read from second deepest RAM (second earliest data), at readAddress + 1
	.readAddress(9'b1)
    );
endmodule