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
    parameter FRACT_BITS = 10,       // Fixed point number fractional part length
    parameter FIXED_POINT_BITS = 18,      // Fixed poin number total length, should be 18
    parameter INT_BITS = FIXED_POINT_BITS - FRACT_BITS,        // Fixed poin number integer part length. The total bit length should sum up to 18
    parameter COEFF_BITS = FRACT_BITS + 1   // The bilinear coefficients width, in the form of Q1.FRACT_BITS, since it is max. 1, the integer part does not need to be longer
    //---------------------------

    //scalings
)(
    input wire clk,                 // Clock input
    input wire rst,                 // Reset input
    
    // Image IO
    
    input wire [CHANNELS*COLOR_DEPTH-1:0] dataIn,    // Pixel data in
    output reg [CHANNELS*COLOR_DEPTH-1:0] dataOut,  // Pixel data out
    
    //the resolution of the original and scaled image should be given
    input wire [ORIG_X_SIZE-1:0] origResolutionX,
    input wire [ORIG_Y_SIZE-1:0] origResolutionY,
    input wire [TF_X_SIZE-1:0] tfResolutionX,
    input wire [TF_Y_SIZE-1:0] tfResolutionY,
    
    //the scaling factors in X and Y direction. ScaleX should be origResolutionX/tfResolutionX
    input wire [FIXED_POINT_BITS-1:0] xScale,
    input wire [FIXED_POINT_BITS-1:0] yScale,
    
    input wire [CHANNELS*COLOR_DEPTH-1:0] px00,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px01,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px10,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px11,
    output reg [CHANNELS*COLOR_DEPTH-1:0] outpx
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

    
    reg [TF_X_SIZE - 1:0]xTfCnt = 1'b0; //initialize column counter on the transformed image to 0
    reg [TF_Y_SIZE - 1:0]yTfCnt = 1'b0; //initialize line counter on the transformed image to 0
    
    reg [ORIG_X_SIZE + FRACT_BITS - 1:0]xOrigCnt = 1'b0;   //initialize column counter on the original image to 0
    reg [ORIG_Y_SIZE + FRACT_BITS - 1:0]yOrigCnt = 1'b0;   //initialize row counter on the original image to 0
    
    reg [COEFF_BITS-1:0]coeff00 = 1'b0; //initialize the upper left coefficint to 0 in the form of Q1.FRACT_BITS 
    reg [COEFF_BITS-1:0]coeff01 = 1'b0; //initialize the upper right coefficint to 0 in the form of Q1.FRACT_BITS 
    reg [COEFF_BITS-1:0]coeff10 = 1'b0; //initialize the lower left coefficint to 0 in the form of Q1.FRACT_BITS 
    reg [COEFF_BITS-1:0]coeff11 = 1'b0; //initialize the lower right coefficint to 0 in the form of Q1.FRACT_BITS 
    
    
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
    
    
    //coefficients for bilinear filtering
    // Backward mapping coefficients
    // multiplying two Q1.FRACT_BITS length numbers, we get one Q2.2*FRAC_BITS length number. 
    //But we only care about the middle Q1.FRAC_BITS length number
    //So in theory, coeffOne and xOrigCnt and therefore xScale and yScale can be half as wide as the bilinear coefficients
    always @ (posedge clk)
    if (rst)begin
        coeff00 <=0;
        coeff01 <=0;
        coeff10 <=0;
        coeff11 <=0;
    end
    else begin
        //1-xfractionalpart * 1-yfractionalpart. Left shift with coeff_bits, because the result is 2*coeff_bits long
        coeff00 <= (((coeffOne - {1'b0,xOrigCnt[FRACT_BITS-1:0]})* (coeffOne - {1'b0,yOrigCnt[FRACT_BITS-1:0]})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}}; 
        coeff01 <= ((({1'b0,xOrigCnt[FRACT_BITS-1:0]})* (coeffOne - {1'b0,yOrigCnt[FRACT_BITS-1:0]})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}};
        coeff10 <= (((coeffOne - {1'b0,yOrigCnt[FRACT_BITS-1:0]})*({1'b0,yOrigCnt[FRACT_BITS-1:0]})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}};
        coeff11 <= ((({1'b0,yOrigCnt[FRACT_BITS-1:0]})* ({1'b0,yOrigCnt[FRACT_BITS-1:0]})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COEFF_BITS{1'b1}}};
        //these have to sum to 1 at any given moment
        //why do we have to & ???
    end
    
    /*
    Somehow, the image data appears in the memory
    */
    reg [CHANNELS*COLOR_DEPTH-1:0] outpx00;
    reg [CHANNELS*COLOR_DEPTH-1:0] outpx01;
    reg [CHANNELS*COLOR_DEPTH-1:0] outpx10;
    reg [CHANNELS*COLOR_DEPTH-1:0] outpx11;
    integer i,j;
    always @ (posedge clk)
    if (rst)begin
        outpx <= 8'h00;
        outpx00 <= 8'h00;
        outpx01 <= 8'h00;
        outpx10 <= 8'h00;
        outpx11 <= 8'h00;
    end
    else begin
        //outpx <= 8'h55;
        //making the px00 fixed point, multiplying with coeff00, and taking the integer bits part
        //Q8.0 * Q1.10 = Q9.10 -> shifting to the right by 10, and taking the last 8 bits only
        outpx <=    ((px00*coeff00)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}} + 
                    ((px01*coeff01)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}} + 
                    ((px10*coeff10)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}} + 
                    ((px11*coeff11)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}};
        outpx00 <=  ((px00*coeff00)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}};
        outpx01 <=  ((px01*coeff01)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}};
        outpx10 <=  ((px10*coeff10)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}};
        outpx11 <=  ((px11*coeff11)>>FRACT_BITS)&{{FRACT_BITS+1{1'b0}}, {COLOR_DEPTH{1'b1}}};
    end
    
    
endmodule