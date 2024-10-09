`timescale 1ns / 1ps


module bilin_buffer_tb();

parameter CHANNELS = 3;
parameter COLOR_DEPTH = 8;      // How many bits are the pixels represented as 
parameter ORIG_X_SIZE = 11;    // Original image width 11 bit for 1080p 
parameter ORIG_Y_SIZE = 11;    // Original image height
parameter TF_X_SIZE = 11;     // Transformed image width
parameter TF_Y_SIZE = 11;      // Transformed image height

//-------------------------
// Fixed point representation properties Q8.10 means 8 integer bits and 10 fractional bits. sign bit is not needed here
parameter FRACT_BITS = 10;       // Fixed poin number fractional part length
parameter FIXED_POINT_BITS = 18;
parameter INT_BITS = FIXED_POINT_BITS - FRACT_BITS;

parameter ORIGRESX = 512; // CHANGE ME
parameter ORIGRESY = 512;// CHANGE ME
parameter TFRESX = 800;// CHANGE ME
parameter TFRESY = 800;// CHANGE ME

wire [ORIG_X_SIZE-1:0]origResolutionX = 11'd512;// CHANGE ME
wire [ORIG_Y_SIZE-1:0]origResolutionY = 11'd512;// CHANGE ME
wire [TF_X_SIZE-1:0]tfResolutionX = 11'd800;// CHANGE ME
wire [TF_Y_SIZE-1:0]tfResolutionY = 11'd800;// CHANGE ME

reg [FIXED_POINT_BITS-1:0] xScale = {14'b00001010001110};  //origResolutionX/tfResolutionX = xScale // CHANGE ME
reg [FIXED_POINT_BITS-1:0] yScale = {14'b00001010001110};  //origResolutionY/tfResolutionY = yScale // CHANGE ME


//reg [CHANNELS*COLOR_DEPTH-1:0] output_array[TFRESX*TFRESY-1:0];    
reg [CHANNELS*COLOR_DEPTH-1:0] input_array[ORIGRESX*ORIGRESY-1:0];

integer file_in, file_out;
initial
begin
    file_in = $fopen("check.raw", "rb");
    file_out = $fopen("check_out.raw", "wb");
    $fread(input_array, file_in);
    $fclose(file_in);
end


reg clk = 1;
reg rst = 1;


wire [ORIG_X_SIZE-1:0] px00XCoord;
wire [ORIG_Y_SIZE-1:0] px00YCoord;

wire [TF_X_SIZE - 1:0] outPxXCoord;
wire [TF_Y_SIZE - 1:0] outPxYCoord;
wire [COLOR_DEPTH*CHANNELS-1:0]outPx;

wire validOutput;
wire doneImage;

reg [COLOR_DEPTH*CHANNELS-1:0] inPx;
always @ (posedge clk)begin
    
    if (validOutput) begin
        $fwrite(file_out,"%c%c%c",outPx[23:16],outPx[15:8],outPx[7:0]);
    end
    if (doneImage) begin
        $fclose(file_out);
        $stop;
    end
    
    inPx <=input_array[((requestRow + 1'b0) * origResolutionX + {{ORIG_X_SIZE{1'b0}},requestCol} + 1'b0)];
end

wire [ORIG_Y_SIZE-1:0] requestRow;
wire [ORIG_X_SIZE-1:0] requestCol;
wire readyForRead;
wire doneProcessing;

wire [COLOR_DEPTH*CHANNELS-1:0] px00;
wire [COLOR_DEPTH*CHANNELS-1:0] px01;
wire [COLOR_DEPTH*CHANNELS-1:0] px10;
wire [COLOR_DEPTH*CHANNELS-1:0] px11;

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
	.readData00(px00),		//Read from deepest RAM (earliest data), at readAddress
	.readData01(px01),		//Read from deepest RAM (earliest data), at readAddress + 1
	.readData10(px10),		//Read from second deepest RAM (second earliest data), at readAddress
	.readData11(px11),		//Read from second deepest RAM (second earliest data), at readAddress + 1
	.readAddress(px00XCoord)
    );



bilinear_filter
#(
    .CHANNELS(CHANNELS),
    .COLOR_DEPTH(COLOR_DEPTH),
    .ORIG_X_SIZE(ORIG_X_SIZE),
    .ORIG_Y_SIZE(ORIG_Y_SIZE),
    .TF_X_SIZE(TF_X_SIZE),
    .TF_Y_SIZE(TF_Y_SIZE),
    .FRACT_BITS(FRACT_BITS),
    .FIXED_POINT_BITS(FIXED_POINT_BITS),
    .ORIGRESX(ORIGRESX),
    .ORIGRESY(ORIGRESX),
    .TFRESX(TFRESX),
    .TFRESY(TFRESY)
)
bilin_uut
(
    .clk(clk),
    .rst(rst),
    .origResolutionX(origResolutionX), 
    .origResolutionY(origResolutionY),
    .tfResolutionX(tfResolutionX),
    .tfResolutionY(tfResolutionY),
    .xScale(xScale),
    .yScale(yScale),
    
    .px00XCoord(px00XCoord),
    .px00YCoord(px00YCoord),
    .readyForRead(readyForRead),
    
    .px00(px00),
    .px01(px01),
    .px10(px10),
    .px11(px11),
    
    .outPxXCoord(outPxXCoord),
    .outPxYCoord(outPxYCoord),
    .outPx(outPx),
    .validOutput(validOutput),
    .doneProcessing(doneProcessing),
    .doneImage(doneImage)
);




always #5
   clk <= ~clk;
   
initial
begin
   rst <= 1;
   #20 
   rst <= 0;
end


endmodule
