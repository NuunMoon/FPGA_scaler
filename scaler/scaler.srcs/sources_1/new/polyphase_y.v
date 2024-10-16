`timescale 1ns / 1ps


module polyphase_y#(
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
    input wire [TF_X_SIZE-1:0] tfResolutionX,
    
    //the scaling factors in X and Y direction. ScaleX should be origResolutionX/tfResolutionX
    input wire [FIXED_POINT_BITS-1:0] yScale,
    
    output reg [ORIG_X_SIZE-1:0] px00YCoord,
    output reg [TF_X_SIZE-1:0] px00XCoord,
    input wire readyForRead,
    
    input wire [CHANNELS*COLOR_DEPTH-1:0] px0,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px1,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px2,
    input wire [CHANNELS*COLOR_DEPTH-1:0] px3,

    output wire [CHANNELS*COLOR_DEPTH-1:0] outPx,
    output wire validOutput,
    output reg doneProcessing,
    output reg doneImage
);

reg [TF_X_SIZE - 1:0]xTfCnt = 1'b0; //initialize column counter on the transformed image to 0

reg [ORIG_Y_SIZE + FRACT_BITS - 1:0]yOrigCnt = 1'b0;   //initialize column counter on the original image to 0

reg [5:0]HPhase = 0;

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
        yOrigCnt <= 0;
        state <= START;
        doneProcessing <= 0;
        doneImage <=0;
        HPhase <=0;
        we <= 0;
    end 
    else
        case (state)
            START: begin
                if (readyForRead) begin
                    state <= PROCESSING;
                end
            end
                PROCESSING: begin
                    if (xTfCnt == tfResolutionX-1) begin
                        // only x counter is full, reset x counter, incement y counter
                        xTfCnt <= 0;
                        //send to DONEROW state
                        state <= DONEROW;
                        HPhase <= 0;
                        yOrigCnt <= yOrigCnt + yScale;
                    end
                    else begin
                        //no counter is full, incement x 
                        xTfCnt <= xTfCnt + 1'b1;
                        if (HPhase == PHASES-1) begin
                            HPhase <= 0;
                        end
                        else
                            HPhase <= HPhase + 1;
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

    
//requesting data

    //saving the fractional and integer parts of the xorigcnt and yorigcnt 

    //-----------------------------------------------------------------
    reg [ORIG_X_SIZE-1:0] yOrigCntSh=0; //making 
    reg [5:0]HPhaseSh [4:0];
    


integer j;
    always @(posedge clk) begin
        if (rst) begin
            yOrigCntSh<=0;
            HPhaseSh[0]<=0;
            HPhaseSh[1]<=0;
            HPhaseSh[2]<=0;
            HPhaseSh[3]<=0;
        end else begin
            //1 clk delay
            //writing the orig px locations to the output
            px00YCoord <= yOrigCnt[ORIG_Y_SIZE + FRACT_BITS - 1:FRACT_BITS];
            px00XCoord <= xTfCnt;
            yOrigCntSh <= yOrigCnt[ORIG_Y_SIZE + FRACT_BITS - 1:FRACT_BITS];
            
            HPhaseSh[0] <= HPhase;
            HPhaseSh[1]<=HPhaseSh[0];
            HPhaseSh[2]<=HPhaseSh[1];
            HPhaseSh[3]<=HPhaseSh[2];
            HPhaseSh[4]<=HPhaseSh[3];
        end
    end


//filter banks 
//in case of 3 phases, 3 banks are necessary, and because of 4 taps, each will contain 4 values
//COEFF_BITS+1 long (12), S1.10 format
reg signed [COEFF_BITS:0]phases[TAPS-1:0][PHASES-1:0];

initial begin
    phases[0][0] = 12'b000000000000;
    phases[1][0] = 12'b000000000000;
    phases[2][0] = 12'b010000000000;
    phases[3][0] = 12'b000000000000;
    
    phases[0][1] = 12'b111100111101;
    phases[1][1] = 12'b000111100111;
    phases[2][1] = 12'b001111001111;
    phases[3][1] = 12'b111100001101;
    
    phases[0][2] = 12'b111100001101;
    phases[1][2] = 12'b001111001111;
    phases[2][2] = 12'b000111100111;
    phases[3][2] = 12'b111100111101;
end

//incoming data gets multiplied here
    reg signed [COLOR_DEPTH + COEFF_BITS +1:0] mult0 [CHANNELS-1:0];
    reg signed [COLOR_DEPTH + COEFF_BITS+1:0] mult1 [CHANNELS-1:0];
    reg signed [COLOR_DEPTH + COEFF_BITS+1:0] mult2 [CHANNELS-1:0];
    reg signed [COLOR_DEPTH + COEFF_BITS+1:0] mult3 [CHANNELS-1:0];
    reg signed [COLOR_DEPTH + COEFF_BITS-FRACT_BITS:0] sum[CHANNELS-1:0];
    reg [COLOR_DEPTH-1:0] res[CHANNELS-1:0];
    
    reg signed [COLOR_DEPTH:0]px0sign[CHANNELS-1:0];
    reg signed [COLOR_DEPTH:0]px1sign[CHANNELS-1:0];
    reg signed [COLOR_DEPTH:0]px2sign[CHANNELS-1:0];
    reg signed [COLOR_DEPTH:0]px3sign[CHANNELS-1:0];
    genvar k;
    generate
        for (k=0;k<CHANNELS;k=k+1) begin
            always @ (posedge clk) begin
                if (rst)begin
                        mult0[k] <= 0;
                        mult1[k] <= 0;
                        mult2[k] <= 0;
                        mult3[k] <= 0;
                        sum[k] <= 0;
                        res[k] <= 0;
                end
                else begin
                    //Q8.0*QS1.10 = QS9.10 -> >> 10 ->Q8.0
                    //1 clk
                    px0sign[k] <= {1'b0,px0[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]};
                    px1sign[k] <= {1'b0,px1[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]};
                    px2sign[k] <= {1'b0,px2[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]};
                    px3sign[k] <= {1'b0,px3[COLOR_DEPTH*(k+1)-1:COLOR_DEPTH*k]};
                    
                    mult0[k] <= px0sign[k] * phases[3][HPhaseSh[1]];
                    mult1[k] <= px1sign[k] * phases[2][HPhaseSh[1]];
                    mult2[k] <= px2sign[k] * phases[1][HPhaseSh[1]];
                    mult3[k] <= px3sign[k] * phases[0][HPhaseSh[1]];
                    sum[k] <= (mult0[k] + mult1[k] + mult2[k] + mult3[k])>> FRACT_BITS;
                    if (sum[k][9])
                        res[k] <= 8'd0;
                    else if (sum[k]>255)
                        res[k] <= 8'd255;
                    else
                        res[k] <= sum[k][7:0];
                end
             end
        end   
    endgenerate

    assign outPx[COLOR_DEPTH*1-1:COLOR_DEPTH*0] = res[0];
    assign outPx[COLOR_DEPTH*2-1:COLOR_DEPTH*1] = res[1];
    assign outPx[COLOR_DEPTH*3-1:COLOR_DEPTH*2] = res[2];
    
    reg [4:0] validInput;
    integer j;
    always @ (posedge clk) begin
        if (state == PROCESSING)
            validInput[0] <= 1;
        else
            validInput[0] <= 0;
        
        for (j=1;j<5;j=j+1)
            validInput[j] <= validInput[j-1];
    end
    assign validOutput = validInput[4];

endmodule