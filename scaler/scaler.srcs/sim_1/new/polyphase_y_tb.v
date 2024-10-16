`timescale 1ns / 1ps

module polyphase_y_tb(

    );
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

parameter ORIGRESX = 768; // CHANGE ME
parameter ORIGRESY = 512;// CHANGE ME
parameter TFRESX = 768;// CHANGE ME
parameter TFRESY = 768;// CHANGE ME

wire [TF_X_SIZE-1:0]origResolutionX = ORIGRESX;// CHANGE ME
wire [TF_X_SIZE-1:0]origResolutionY = ORIGRESY;// CHANGE ME
wire [TF_X_SIZE-1:0]tfResolutionX = TFRESX;// CHANGE ME
wire [TF_X_SIZE-1:0]tfResolutionY = TFRESY;// CHANGE ME

reg [FIXED_POINT_BITS-1:0] xScale = {18'b000000001010101010};  //origResolutionX/tfResolutionX = xScale // CHANGE ME
reg [FIXED_POINT_BITS-1:0] yScale = {18'b000000001010101010};  //origResolutionY/tfResolutionY = yScale // CHANGE ME


//reg [CHANNELS*COLOR_DEPTH-1:0] output_array[TFRESX*TFRESY-1:0];    
reg [CHANNELS*COLOR_DEPTH-1:0] input_array[ORIGRESX*ORIGRESY-1:0];

integer file_in, file_out;
initial begin
    file_in = $fopen("lena_out_768_512.raw", "rb");
    file_out = $fopen("lena_out_768_768.raw", "wb");
    $fread(input_array, file_in);
    $fclose(file_in);
end


reg clk = 1;
reg rst = 1;

reg  [CHANNELS*COLOR_DEPTH-1:0]px0;
reg  [CHANNELS*COLOR_DEPTH-1:0]px1;
reg  [CHANNELS*COLOR_DEPTH-1:0]px2;
reg  [CHANNELS*COLOR_DEPTH-1:0]px3;

wire [ORIG_X_SIZE-1:0] px00XCoord;
wire [ORIG_Y_SIZE-1:0] px00YCoord;

wire [COLOR_DEPTH*CHANNELS-1:0]outPx;

wire validOutput;
wire doneImage;


reg [ORIG_Y_SIZE-1:0]rowCnt = 0;
always @ (posedge clk)begin
    if (validOutput) begin
        $fwrite(file_out,"%c%c%c",outPx[23:16],outPx[15:8],outPx[7:0]);
    end

    if (px00YCoord == origResolutionY) begin
        $fclose(file_out);
        $stop;
    end
    
    //pxInput <=input_array[((px00YCoord + 1'b0) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 1'b0)];
    if (px00YCoord == 0) begin
        px0<=0;
        px1 <=input_array[((px00YCoord + 2'd0) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
        px2 <=input_array[((px00YCoord + 2'd1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
        px3 <=input_array[((px00YCoord + 2'd2) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
    end
    else if (px00YCoord == ORIGRESY-2) begin
        px0 <=input_array[((px00YCoord - 2'd1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} - 2'd0)];
        px1 <=input_array[((px00YCoord + 2'd0) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
        px2 <=input_array[((px00YCoord + 2'd1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
        px3 <=0;
    end
    else begin
        px0 <=input_array[((px00YCoord - 2'd1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} - 2'd0)];
        px1 <=input_array[((px00YCoord + 2'd0) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
        px2 <=input_array[((px00YCoord + 2'd1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
        px3 <=input_array[((px00YCoord + 2'd2) * origResolutionX + {{ORIG_X_SIZE{1'b0}},px00XCoord} + 2'd0)];
    end
end
reg readyForRead = 1;
wire doneProcessing;

polyphase_y
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
    .TFRESY(TFRESY),
    
    .PHASES(3),
    .TAPS(4)
)
poly_y_uut
(
    .clk(clk),
    .rst(rst),
    .origResolutionX(origResolutionX), 
    .tfResolutionX(tfResolutionX),
    .yScale(yScale),
    
    .px00YCoord(px00YCoord),
    .px00XCoord(px00XCoord),
    .readyForRead(readyForRead),
    
    .px0(px0),
    .px1(px1),
    .px2(px2),
    .px3(px3),
    
    .outPx(outPx),
    .validOutput(validOutput),
    .doneProcessing(doneProcessing),
    .doneImage(doneImage)
);

reg a = 1;
    
always @ (posedge clk) begin
    if (!rst) begin
        if (doneProcessing && a) begin
            readyForRead <=1;
            a<=0;
            rowCnt <= rowCnt + 1;
        end
        else if (doneProcessing && !a) begin
            readyForRead <=1;
        end
        else begin
            readyForRead <=0;
            a <= 1;
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
