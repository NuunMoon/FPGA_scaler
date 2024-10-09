`timescale 1ns / 1ps


module backwards_mapping_tb();
parameter CHANNELS = 1;
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

reg clk = 1;
reg rst = 1;

reg [FIXED_POINT_BITS-1:0] xScale = {8'b0,10'b1010001100};  //origResolutionX/tfResolutionX = xScale
reg [FIXED_POINT_BITS-1:0] yScale = {8'b0,10'b0110110110};  //origResolutionY/tfResolutionY = yScale
backwards_mapping 
#(
    .CHANNELS(CHANNELS),
    .COLOR_DEPTH(COLOR_DEPTH),
    .ORIG_X_SIZE(ORIG_X_SIZE),
    .ORIG_Y_SIZE(ORIG_Y_SIZE),
    .TF_X_SIZE(TF_X_SIZE),
    .TF_Y_SIZE(TF_Y_SIZE),
    .FRACT_BITS(FRACT_BITS),
    .FIXED_POINT_BITS(FIXED_POINT_BITS)
)
uut
(
    .clk(clk),
    .rst(rst),
    .dataIn(),
    .dataOut(),
    .origResolutionX(11'd8),
    .origResolutionY(11'd4),
    .tfResolutionX(11'd12),
    .tfResolutionY(11'd8),
    .xScale(xScale),
    .yScale(yScale),
    .px00(24'hffffff),
    .px01(24'hffffff),
    .px10(24'hffffff),
    .px11(24'hffffff)
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
