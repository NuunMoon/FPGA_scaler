`timescale 1ns / 1ps

module polyphase_filter#(
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
    
    parameter PHASES = 3,
    parameter TAPS = 4,
    
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
    
    input wire [CHANNELS*COLOR_DEPTH-1:0] px0,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px1,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px2,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px3,
    
    output reg [ORIG_X_SIZE-1:0] outPxXCoord,
    output reg [ORIG_Y_SIZE-1:0] outPxYCoord,
    output wire [CHANNELS*COLOR_DEPTH-1:0] outPx,
    output wire validOutput,
    output reg doneProcessing,
    output reg doneImage
);

reg [TF_X_SIZE - 1:0]xTfCnt = 1'b0; //initialize column counter on the transformed image to 0
reg [TF_Y_SIZE - 1:0]yTfCnt = 1'b0; //initialize line counter on the transformed image to 0

reg [ORIG_X_SIZE - 1:0]xOrigCntVScale = 1'b0; //initialize column counter on the transformed image to 0
reg [ORIG_Y_SIZE - 1:0]yOrigCntVScale = 1'b0; //initialize line counter on the transformed image to 0

reg [ORIG_X_SIZE + FRACT_BITS - 1:0]xOrigCnt = 1'b0;   //initialize column counter on the original image to 0
reg [ORIG_Y_SIZE + FRACT_BITS - 1:0]yOrigCnt = 1'b0;   //initialize row counter on the original image to 0

reg [3:0]VPhase = 4'd0;
reg [3:0]HPhase = 4'd0;

reg [2:0] state;
localparam START = 0;
localparam PROCESSING = 1;
localparam DONEROW =2;
localparam DONEIMAGE = 3;
localparam VSCALE = 4;
localparam HSCALE = 5;


reg we = 0;

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
        HPhase <=0;
        VPhase <=0;
        xOrigCntVScale <=0;
        yOrigCntVScale <=0;
        we <= 0;
    end 
    else
        case (state)
            START: begin
                if (readyForRead) begin
                    state <= VSCALE;
                    doneProcessing <= 0;
                end
            end
            HSCALE: begin
                if (xTfCnt == tfResolutionX-1 & yTfCnt == tfResolutionY-1) begin 
                    // x and y counter full, reset both counters
                    xTfCnt <= 0; 
                    yTfCnt <= 0;
                    xOrigCnt <=0; // Line counter reset on orig and tf image
                    yOrigCnt <=0;
                    HPhase <=0;
                    //done with image, send to DONEIMAGE state
                    state <= DONEIMAGE;
                end
                else if (xTfCnt == tfResolutionX-1) begin
                    // only x counter is full, reset x counter, incement y counter
                    xTfCnt <= 0;
                    xOrigCnt <=0;
                    yTfCnt <= yTfCnt + 1'b1;
                    yOrigCnt <= yOrigCnt + yScale;
                    HPhase <=0;
                    //send to DONEROW state
                    state <= DONEROW;
                end
                else begin
                    //no counter is full, incement x 
                    xTfCnt <= xTfCnt + 1'b1;
                    xOrigCnt <= xOrigCnt + xScale;
                    //incrementing the current phase, if end of phase, reset
                    if (HPhase == PHASES-1)
                        HPhase <= 0;
                    else
                        HPhase <= HPhase + 1;
                end

            end
            VSCALE: begin
                if (xOrigCntVScale == origResolutionX-1) begin
                    //send to DONEROW state
                    
                    xOrigCntVScale <= 0;
                    state <= HSCALE;
                    if (VPhase == PHASES-1)
                        VPhase <= 0;
                    else
                        VPhase <= VPhase + 1;
                end
                else begin
                    xOrigCntVScale <= xOrigCntVScale + 1;
                end

            end
            
            DONEROW: begin
                if (readyForRead) begin
                    state <= VSCALE;
                    yOrigCntVScale <= yOrigCntVScale + 1;
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

    
//requesting data

//-----------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        //--------------------------------------------------------
        
    end else begin 
        //--------------------------------------------------------
        
        //1 clk delay
        px00XCoord <= xOrigCntVScale;
        if ( xOrigCntVScale == 0 ) begin
            px00YCoord <= yOrigCntVScale;
        end else if ( xOrigCntVScale == 1 ) begin
            px00YCoord <= yOrigCntVScale-1;
        end else begin
            px00YCoord <= yOrigCntVScale-2;
        end
    end
end


//filter banks 
//in case of 3 phases, 3 banks are necessary, and because of 4 taps, each will contain 4 values
reg [COEFF_BITS-1:0]phase0[3:0];
reg [COEFF_BITS-1:0]phase1[3:0];
reg [COEFF_BITS-1:0]phase2[3:0];
reg [COEFF_BITS-1:0]currentBank[3:0];
always@(posedge clk) begin 
   //set current filter to the one specified by Vphase and Hphase

end

//incoming data gets multiplied here
    reg [FIXED_POINT_BITS-1:0] mult0 [CHANNELS-1:0];
    reg [FIXED_POINT_BITS-1:0] mult1 [CHANNELS-1:0];
    reg [FIXED_POINT_BITS-1:0] mult2 [CHANNELS-1:0];
    reg [FIXED_POINT_BITS-1:0] mult3 [CHANNELS-1:0];
    reg [CHANNELS*COLOR_DEPTH-1:0] multres[CHANNELS-1:0];
    genvar k;
    generate
        for (k=0;k<CHANNELS;k=k+1) begin
            always @ (posedge clk)
            if (rst)begin
                    mult0[k] <= 0;
                    mult1[k] <= 0;
                    mult2[k] <= 0;
                    mult3[k] <= 0;
                    multres[k] <= 0;
            end
            else begin
                //Q8.0*Q1.10 = Q9.10 -> >> 10 ->Q8.0
                //1 clk
                mult0[k] <= px0[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k] * currentBank[0];
                mult1[k] <= px1[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k] * currentBank[1];
                mult2[k] <= px2[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k] * currentBank[2];
                mult3[k] <= px3[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k] * currentBank[3];
                multres[k] <= mult0[k] + mult1[k] + mult2[k] + mult3[k]

            end
            
            
        end   
    endgenerate


integer i;
reg [COLOR_DEPTH + FIXED_POINT_BITS-1:0]HScaleElements[3:0];
initial begin
    for (i=0;i<4;i=i+1) begin
        HScaleElements[i] = 0;
    end
end


always@(posedge clk) begin
    HScaleElements[1] <= HScaleElements[0];
    HScaleElements[2] <= HScaleElements[1];
    HScaleElements[3] <= HScaleElements[2];
end

ram #(
    .DATA_WIDTH(FIXED_POINT_BITS),
    .ADDRESS_WIDTH(ORIG_X_SIZE)
) ram_row(
    .clk( clk ),

    .addrA( px00XCoord ),	
    .dataA(  ),													
    .weA(we),
    .outA()
);


endmodule
