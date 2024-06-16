`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.03.2024 22:26:53
// Design Name: 
// Module Name: backwards_mapping
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module backwards_mapping #(
    // Image properties
    parameter CHANNELS = 3,         // for R G B
    parameter COLOR_DEPTH = 8,      // How many bits are the pixels represented as 
    parameter ORIG_X_SIZE = 11,    // Original image width 11 bit for 1080p 
    parameter ORIG_Y_SIZE = 11,    // Original image height
    parameter TF_X_SIZE = 11,     // Transformed image width
    parameter TF_Y_SIZE = 11,      // Transformed image height
    
    //-------------------------
    // Fixed point representation properties Q8.10 means 8 integer bits and 10 fractional bits. sign bit is not needed here
    parameter FRACT_BITS = 14,       // Fixed point number fractional part length
    parameter FIXED_POINT_BITS = 18,      // Fixed poin number total length, should be 18
    parameter INT_BITS = FIXED_POINT_BITS - FRACT_BITS,        // Fixed poin number integer part length. The total bit length should sum up to 18
    parameter COEFF_BITS = FRACT_BITS + 1   // The bilinear coefficients width, in the form of Q1.FRACT_BITS, since it is max. 1, the integer part does not need to be longer
    //---------------------------
    

    //scalings
)(
    input wire clk,                 // Clock input
    input wire rst,                 // Reset input
    
    
    //the resolution of the original and scaled image should be given
    input wire [ORIG_X_SIZE-1:0] origResolutionX,
    input wire [ORIG_Y_SIZE-1:0] origResolutionY,
    input wire [TF_X_SIZE-1:0] tfResolutionX,
    input wire [TF_Y_SIZE-1:0] tfResolutionY,
    
    //the scaling factors in X and Y direction. ScaleX should be origResolutionX/tfResolutionX
    input wire [FIXED_POINT_BITS-1:0] xScale,
    input wire [FIXED_POINT_BITS-1:0] yScale,
    
    input wire [COLOR_DEPTH-1:0] px00,
    input wire [COLOR_DEPTH-1:0] px01,
    input wire [COLOR_DEPTH-1:0] px10,
    input wire [COLOR_DEPTH-1:0] px11,
    output reg [COLOR_DEPTH-1:0] outpx
);
/*
    We need to loop on the whole tf_data, and implement the backwards mapping algorithm on 
    the image. To do this, we loop through the transformed image's pixels. 
    If we are on the (U,V) pixel on the transformed image (U and V are integers), the way to
    determine the color of that pixel, is to get what color the corresponding (X,Y) pixel is on the 
    original image. To do this, we take the ratio of the two image's row and column sizes, and multiply the
    result with the coordinates of the transformed image.
    
    For example: original image (32*32), transformed image (64*64). It can easily be seen, that
    every pixel from the original image, maps to 4 pixels on the transformed image.
    Using the formula: (U,V) -> (ORIG_X / TF_X * U, ORIG_Y / TF_Y * V)
*/
//(* ram_style = "block" *) 

    
    reg [TF_X_SIZE - 1:0]xTfCnt = 1'b0; //initialize column counter on the transformed image to 0
    reg [TF_Y_SIZE - 1:0]yTfCnt = 1'b0; //initialize line counter on the transformed image to 0
    
    reg [ORIG_X_SIZE + FRACT_BITS - 1:0]xOrigCnt = 1'b0;   //initialize column counter on the original image to 0
    reg [ORIG_Y_SIZE + FRACT_BITS - 1:0]yOrigCnt = 1'b0;   //initialize row counter on the original image to 0
    
    reg [COLOR_DEPTH-1:0] upperBilinRes;
    reg [COLOR_DEPTH-1:0] lowerBilinRes;
    reg [COLOR_DEPTH-1:0] middleBilinRes;
    //Coefficient value of one, format Q1.FRACT_BITS
    wire [COEFF_BITS-1:0]coeffOne = {1'b1, {(COEFF_BITS-1){1'b0}}};   //One in MSb, zeros elsewhere
    
    
    //original and transformed image pixel counters
    always @(posedge clk) begin
        // Loop through every pixel of the transformed image and assign it a value based on the backwards mapping
        if (rst) begin
            xTfCnt <= 0;
            yTfCnt <= 0;
            xOrigCnt <= 0;
            yOrigCnt <= 0;
        end else begin 
            if (xTfCnt == tfResolutionX - 1 & yTfCnt == tfResolutionY - 1) begin 
                // x and y counter full, reset both counters
                xTfCnt <= 0; 
                yTfCnt <= 0;
                xOrigCnt <=0; // Line counter reset on orig and tf image
                yOrigCnt <=0;
                $writememh("C:/Users/gilic/OneDrive/EGYETEM/Vik_msc1/scaler/lena_gray_scaled.raw", output_array);
            end
            else if (xTfCnt == tfResolutionX - 1) begin
                // only x counter is full, reset x counter, incement y counter
                xTfCnt <= 0;
                xOrigCnt <=0;
                yTfCnt <= yTfCnt + 1'b1;
                yOrigCnt <= yOrigCnt + yScale;
            end
            else begin
                //no counter is full, incement x 
                xTfCnt <= xTfCnt + 1'b1;
                xOrigCnt <= xOrigCnt + xScale;
            end
        end 

    end
    
    //saving the fractional and integer parts of the xorigcnt and yorigcnt 
    reg [FRACT_BITS-1:0] xOrigCntFrac;
    reg [ORIG_X_SIZE + FRACT_BITS - 1:FRACT_BITS] xOrigCntInt;
    reg [FRACT_BITS-1:0] yOrigCntFrac;
    reg [ORIG_Y_SIZE + FRACT_BITS - 1:FRACT_BITS] yOrigCntInt;
    reg [TF_X_SIZE - 1:0]xTfCntDel; //initialize column counter on the transformed image to 0
    reg [TF_Y_SIZE - 1:0]yTfCntDel; //initialize line counter on the transformed image to 0
    always @(posedge clk) begin
        if (rst) begin
            xOrigCntFrac <= 0;
            xOrigCntInt <= 0;
            yOrigCntFrac <= 0;
            yOrigCntInt <= 0;
            xTfCntDel <=0;
            yTfCntDel <=0;
        end else begin 
            xOrigCntFrac <= xOrigCnt[FRACT_BITS-1:0];
            xOrigCntInt <= xOrigCnt[ORIG_X_SIZE + FRACT_BITS - 1:FRACT_BITS];
            yOrigCntFrac <= yOrigCnt[FRACT_BITS-1:0];
            yOrigCntInt <= yOrigCnt[ORIG_Y_SIZE + FRACT_BITS - 1:FRACT_BITS];
            xTfCntDel <=xTfCnt;
            yTfCntDel <=yTfCnt;
        end
    end
    /*
    Somehow, the image data appears in the memory
    */
    
reg [7:0] output_array[256*256-1:0];    
reg [7:0] input_array[512*512-1:0];
initial $readmemh("C:/Users/gilic/OneDrive/EGYETEM/Vik_msc1/scaler/lena_gray.txt", input_array);

reg [ORIG_Y_SIZE+ORIG_X_SIZE-1:0]seged; 
    always @ (posedge clk)
    if (rst)begin
        upperBilinRes <=0;
        lowerBilinRes <=0;
        middleBilinRes <=0;
    end
    else begin
        seged<=yTfCntDel * tfResolutionX + xTfCntDel;
        upperBilinRes  <= (((input_array[yOrigCntInt * origResolutionX + {{ORIG_X_SIZE{1'b0}},xOrigCntInt}]
         *          (coeffOne - {1'b0,xOrigCntFrac})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}}) +
                          (((input_array[yOrigCntInt * origResolutionX + {{ORIG_X_SIZE{1'b0}},xOrigCntInt} + 1'b1]
         *                      {1'b0,xOrigCntFrac})  >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}});
        lowerBilinRes  <= (((input_array[(yOrigCntInt + 1'b1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},xOrigCntInt}]
        *          (coeffOne - {1'b0,xOrigCntFrac})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}}) + 
                          (((input_array[(yOrigCntInt + 1'b1) * origResolutionX + {{ORIG_X_SIZE{1'b0}},xOrigCntInt} + 1'b1]
        *                      {1'b0,xOrigCntFrac})  >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}});
        //one clk later
        middleBilinRes  <= (((upperBilinRes * (coeffOne - {1'b0,yOrigCntFrac})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}}) + 
                          (((lowerBilinRes *             {1'b0,yOrigCntFrac})  >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}}); 
                          
        output_array[yTfCntDel * tfResolutionX + {{ORIG_Y_SIZE{1'b0}},xTfCntDel}]  <= middleBilinRes;
        end


endmodule