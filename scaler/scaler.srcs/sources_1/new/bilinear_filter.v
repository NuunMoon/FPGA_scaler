`timescale 1ns / 1ps

module bilinear_filter#(
    // Image properties
    parameter CHANNELS = 3,
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
    parameter COEFF_BITS = FRACT_BITS + 1,   // The bilinear coefficients width, in the form of Q1.FRACT_BITS, since it is max. 1, the integer part does not need to be longer
    //---------------------------
    parameter ORIGRESX = 512,
    parameter ORIGRESY = 512,
    parameter TFRESX = 512,
    parameter TFRESY = 512,
    
    
    
    parameter DELAY = 1
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
    
    output reg [ORIG_X_SIZE-1:0] px00XCoord,
    output reg [ORIG_Y_SIZE-1:0] px00YCoord,
    input wire readyForRead,
    
    input wire [CHANNELS*COLOR_DEPTH-1:0] px00,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px01,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px10,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px11,
    
    output reg [ORIG_X_SIZE-1:0] outPxXCoord,
    output reg [ORIG_Y_SIZE-1:0] outPxYCoord,
    output wire [CHANNELS*COLOR_DEPTH-1:0] outPx,
    output wire validOutput,
    output reg doneProcessing,
    output reg doneImage
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


    reg [1:0] state;
    localparam START = 0;
    localparam PROCESSING = 1;
    localparam DONEROW =2;
    localparam DONEIMAGE = 3;
    
    //original and transformed image pixel counters
    always @(posedge clk) begin
        // Loop through every pixel of the transformed image and assign it a value based on the backwards mapping
        if (rst) begin
            xTfCnt <= 0;
            yTfCnt <= 0;
            xOrigCnt <= 0;
            yOrigCnt <= 0;
            state <= START;
            doneProcessing <= 0;
            doneImage <=0;
        end 
        else
            case (state)
                START: begin
                    if (readyForRead) begin
                        state <= PROCESSING;
                        doneProcessing <= 0;
                    end
                end
                PROCESSING: begin
                    if (xTfCnt == tfResolutionX-1 & yTfCnt == tfResolutionY-1) begin 
                        // x and y counter full, reset both counters
                        xTfCnt <= 0; 
                        yTfCnt <= 0;
                        xOrigCnt <=0; // Line counter reset on orig and tf image
                        yOrigCnt <=0;
                        //done with image, send to DONEIMAGE state
                        state <= DONEIMAGE;
                    end
                    else if (xTfCnt == tfResolutionX-1) begin
                        // only x counter is full, reset x counter, incement y counter
                        xTfCnt <= 0;
                        xOrigCnt <=0;
                        yTfCnt <= yTfCnt + 1'b1;
                        yOrigCnt <= yOrigCnt + yScale;
                        //send to DONEROW state
                        state <= DONEROW;
                    end
                    else begin
                        //no counter is full, incement x 
                        xTfCnt <= xTfCnt + 1'b1;
                        xOrigCnt <= xOrigCnt + xScale;
                    end
                end
                
                DONEROW: begin
                    if (readyForRead) begin
                        state <= PROCESSING;
                        doneProcessing <= 0;
                    end
                    else
                        doneProcessing <= 1;
                end
                DONEIMAGE: begin
                    //state <= DONEIMAGE;
                    doneProcessing <= 1;
                    if (!validOutput)
                        doneImage <=1;
                end
            endcase
    end
    
    //saving the fractional and integer parts of the xorigcnt and yorigcnt 

    //-----------------------------------------------------------------
    reg [FRACT_BITS-1:0] xOrigCntFracSh=0; //making 
    reg [FRACT_BITS-1:0] yOrigCntFracSh=0; //making 
    
    reg [FRACT_BITS-1:0]xBlend=0;
    reg [FRACT_BITS-1:0]yBlend=0;
    
    reg [3*TF_X_SIZE - 1:0] outPxXCoordSh={(DELAY+2)*TF_X_SIZE{1'b1}};
    reg [3*TF_Y_SIZE - 1:0] outPxYCoordSh={(DELAY+2)*TF_X_SIZE{1'b1}};
    always @(posedge clk) begin
        if (rst) begin
            //--------------------------------------------------------
            
        end else begin 
            //--------------------------------------------------------
            
            //1 clk delay
            
            //writing the orig px locations to the output
            px00XCoord <= xOrigCnt[ORIG_X_SIZE + FRACT_BITS - 1:FRACT_BITS];
            px00YCoord <= yOrigCnt[ORIG_Y_SIZE + FRACT_BITS - 1:FRACT_BITS];
            
            xOrigCntFracSh <= {xOrigCnt[FRACT_BITS-1:0]};
            yOrigCntFracSh <= {yOrigCnt[FRACT_BITS-1:0]};
            
            //1 clk delay
            xBlend <=xOrigCntFracSh[FRACT_BITS-1:0];
            yBlend <=yOrigCntFracSh[FRACT_BITS-1:0];
            
            outPxXCoordSh<= {xTfCnt,outPxXCoordSh[3*TF_X_SIZE - 1:TF_X_SIZE]};
            outPxYCoordSh<= {yTfCnt,outPxYCoordSh[3*TF_Y_SIZE - 1:TF_Y_SIZE]};
            
            outPxXCoord<=outPxXCoordSh[TF_X_SIZE - 1:0];
            outPxYCoord<=outPxYCoordSh[TF_Y_SIZE - 1:0];
        end
    end
    
    reg [COLOR_DEPTH-1:0] upperBilinRes [CHANNELS-1:0];
    reg [COLOR_DEPTH-1:0] lowerBilinRes [CHANNELS-1:0];
    reg [COLOR_DEPTH-1:0] middleBilinRes [CHANNELS-1:0];
    //Coefficient value of one, format Q1.FRACT_BITS
    
    wire [FRACT_BITS:0]coeffOne = {1'b1, {(FRACT_BITS){1'b0}}};   //One in MSb, zeros elsewhere

    genvar k;
    generate
        for (k=0;k<CHANNELS;k=k+1) begin
            always @ (posedge clk)
            if (rst)begin
                    upperBilinRes[k] <= 0;
                    lowerBilinRes[k] <= 0;
                    middleBilinRes[k] <= 0;
            end
            else begin
                //Q8.0*Q1.10 = Q9.10 -> >> 10 ->Q8.0
                //1 clk
                
                    upperBilinRes[k]  <= (((px00[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]
                    *          (coeffOne - {1'b0,xBlend})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COLOR_DEPTH{1'b1}}}) +
                                      (((px01[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]
                    *                      {1'b0,xBlend})  >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COLOR_DEPTH{1'b1}}});
                    lowerBilinRes[k]  <= (((px10[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]
                    *          (coeffOne - {1'b0,xBlend})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COLOR_DEPTH{1'b1}}}) + 
                                      (((px11[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]
                    *                      {1'b0,xBlend})  >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COLOR_DEPTH{1'b1}}});
                    //one clk later
                    //1 clk
                    middleBilinRes[k]  <= (((upperBilinRes[k]
                    *          (coeffOne - {1'b0,yBlend})) >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COLOR_DEPTH{1'b1}}}) +
                                      (((lowerBilinRes[k]
                    *                      {1'b0,yBlend})  >> FRACT_BITS)&{{COEFF_BITS{1'b0}}, {COLOR_DEPTH{1'b1}}});
            end
            
            
        end   
    endgenerate
    
    assign outPx[COLOR_DEPTH*1-1:COLOR_DEPTH*0] = middleBilinRes[0];
    assign outPx[COLOR_DEPTH*2-1:COLOR_DEPTH*1] = middleBilinRes[1];
    assign outPx[COLOR_DEPTH*3-1:COLOR_DEPTH*2] = middleBilinRes[2];
    
    reg [2:0] validInput;
    integer j;
    always @ (posedge clk) begin
        if (state == PROCESSING)
            validInput[0] <= 1;
        else
            validInput[0] <= 0;
        
        for (j=1;j<3;j=j+1)
            validInput[j] <= validInput[j-1];
    end
    assign validOutput = validInput[2];
endmodule