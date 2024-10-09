`timescale 1ns / 1ps

module bilinear_filter_tb();
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
parameter TFRESX = 1024;// CHANGE ME
parameter TFRESY = 1024;// CHANGE ME

wire [TF_X_SIZE-1:0]origResolutionX = 11'd512;// CHANGE ME
wire [TF_X_SIZE-1:0]origResolutionY = 11'd512;// CHANGE ME
wire [TF_X_SIZE-1:0]tfResolutionX = 11'd1024;// CHANGE ME
wire [TF_X_SIZE-1:0]tfResolutionY = 11'd1024;// CHANGE ME

reg [FIXED_POINT_BITS-1:0] xScale = {14'b00000111111111};  //origResolutionX/tfResolutionX = xScale // CHANGE ME
reg [FIXED_POINT_BITS-1:0] yScale = {14'b00000111111111};  //origResolutionY/tfResolutionY = yScale // CHANGE ME


//reg [CHANNELS*COLOR_DEPTH-1:0] output_array[TFRESX*TFRESY-1:0];    
reg [CHANNELS*COLOR_DEPTH-1:0] input_array[ORIGRESX*ORIGRESY-1:0];

integer file_in, file_out;
initial
begin
    file_in = $fopen("lena.raw", "rb");
    file_out = $fopen("lena_out_1024_1024.raw", "wb");
    $fread(input_array, file_in);
    $fclose(file_in);
end


reg clk = 1;
reg rst = 1;

reg  [CHANNELS*COLOR_DEPTH-1:0]px00;
reg  [CHANNELS*COLOR_DEPTH-1:0]px01;
reg  [CHANNELS*COLOR_DEPTH-1:0]px10;
reg  [CHANNELS*COLOR_DEPTH-1:0]px11;

wire [ORIG_X_SIZE-1:0] px00XCoord;
wire [ORIG_Y_SIZE-1:0] px00YCoord;

wire [TF_X_SIZE - 1:0] outPxXCoord;
wire [TF_Y_SIZE - 1:0] outPxYCoord;
wire [COLOR_DEPTH*CHANNELS-1:0]outPx;

wire validOutput;
wire doneImage;
wire [7:0] test;
assign test = outPx[7:0];

always @ (posedge clk)begin
    
    if (validOutput) begin
        $fwrite(file_out,"%c%c%c",outPx[23:16],outPx[15:8],outPx[7:0]);
    end
    if (doneImage) begin
        $fclose(file_out);
        $stop;
    end
    
    px00 <=input_array[((px00YCoord + 1'b0) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 1'b0)];
    px01 <=input_array[((px00YCoord + 1'b0) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 1'b1)];
    px10 <=input_array[((px00YCoord + 1'b1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 1'b0)];
    px11 <=input_array[((px00YCoord + 1'b1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 1'b1)];
end


reg readyForRead = 1;
wire doneProcessing;
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

always @ (posedge clk) begin
    if (!rst) begin
        if (doneProcessing) begin
            readyForRead <=1;
        end
        else begin
            readyForRead <=0;
        end
    end
end


always #5
   clk <= ~clk;
   
initial
begin
   rst <= 1;
   #20 
   rst <= 0;
end


endmodule
