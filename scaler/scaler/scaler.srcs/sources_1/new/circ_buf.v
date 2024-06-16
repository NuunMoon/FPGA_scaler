`timescale 1ns / 1ps


module circ_buf#(
	parameter DATA_WIDTH = 8, // pixel depth
    parameter BUFFER_SIZE = 2, // 2**BUFFER_SIZE lines are stored at maximum
    parameter ORIG_X_SIZE = 8,    // Original image width 11 bit for 1080p 
    parameter ORIG_Y_SIZE = 8,    // Original image height
    parameter ORIGRESX = 256,
    parameter ORIGRESY = 256,
    parameter NUMROWSTOSTORE = 2,
    parameter NUMROWSTOSTOREHALF = NUMROWSTOSTORE/2,
    //-------------------------
    // Fixed point representation properties Q8.10 means 8 integer bits and 10 fractional bits. sign bit is not needed here
    parameter FRACT_BITS = 10,       // Fixed point number fractional part length
    parameter FIXED_POINT_BITS = 18,      // Fixed point number total length, should be 18
    parameter INT_BITS = FIXED_POINT_BITS - FRACT_BITS,        // Fixed poin number integer part length. The total bit length should sum up to 18
    parameter COEFF_BITS = FRACT_BITS + 1   // The bilinear coefficients width, in the form of Q1.FRACT_BITS, since it is max. 1, the integer part does not need to be longer
    //---------------------------
    
)(
	input wire 						clk,
	input wire 						rst,
	input wire                      start,

	input wire [DATA_WIDTH-1:0]		writeData,
	output wire                     writeDone,

	output reg  [ORIG_Y_SIZE-1:0]  requestRow,
	output reg  [ORIG_X_SIZE-1:0]  requestCol,
	input wire                     dInValid,
	
	input wire                     doneProcessing,
	input wire [FIXED_POINT_BITS-1:0] yScale,
	
	output reg                    readyForRead,
	output wire [DATA_WIDTH-1:0]	readData00,		//Read from deepest RAM (earliest data), at readAddress
	output wire [DATA_WIDTH-1:0]	readData01,		//Read from deepest RAM (earliest data), at readAddress + 1
	output wire [DATA_WIDTH-1:0]	readData10,		//Read from second deepest RAM (second earliest data), at readAddress
	output wire [DATA_WIDTH-1:0]	readData11,		//Read from second deepest RAM (second earliest data), at readAddress + 1
	input wire [ORIG_X_SIZE-1:0]	readAddress
    );
    
reg [BUFFER_SIZE-1:0]		writeSelect;
reg [BUFFER_SIZE-1:0]		readSelect;
reg writeEnable;
reg	forceRead; // to overwrite teh exception when write and read address are the same. This happens at the last line of an image

wire [DATA_WIDTH-1:0] ramDataOutA [2**BUFFER_SIZE-1:0];
wire [DATA_WIDTH-1:0] ramDataOutB [2**BUFFER_SIZE-1:0];
//generating the RAM blocks 
generate
genvar i;
	for(i = 0; i < 2**BUFFER_SIZE; i = i + 1)
		begin : ram_generate
			ram #(
				.DATA_WIDTH(DATA_WIDTH),
				.ADDRESS_WIDTH(ORIG_X_SIZE)
			) ram_inst_i(
				.clk( clk ),
				
				//Port A is written to as well as read from. When writing, this port cannot be read from.
				//As long as the buffer is large enough, this will not cause any problem.
				.addrA( ((writeSelect == i) && !forceRead && writeEnable) ? requestCol : readAddress ),	//&& writeEnable is 
				//to allow the full buffer to be used. After the buffer is filled, write is advanced, so writeSelect
				//and readSelect are the same. The full buffer isn't written to, so this allows the read to work properly.
				.dataA( writeData ),													
				.weA( ((writeSelect == i) && !forceRead) ? writeEnable : 1'b0 ),
				.outA( ramDataOutA[i] ),
				
				//portB is only read from, we are reading the next pixel 
				.addrB( readAddress + 1'b1 ),
				.dataB( writeData ),
				.weB( 1'b0 ),
				.outB( ramDataOutB[i] )
			);
		end
endgenerate
    
//Select which ram to read from
wire [BUFFER_SIZE-1:0]	readSelect0 = readSelect;
wire [BUFFER_SIZE-1:0]	readSelect1 = readSelect+1;

//Steer the output data to the right ports
assign readData00 = ramDataOutA[readSelect0];
assign readData01 = ramDataOutB[readSelect0];
assign readData10 = ramDataOutA[readSelect1];
assign readData11 = ramDataOutB[readSelect1];
    

localparam startState = 0;
localparam afterStartState = 1;


localparam incrCompState = 2;
localparam rowDiffCalc = 3;
localparam nextRowCalcState = 4;

localparam procState = 5;
localparam finishedState = 6;


localparam finishedImageState = 7;

reg [2:0]state;




reg [ORIG_Y_SIZE + FRACT_BITS - 1:0]yOrigCnt;   //initialize row counter on the original image to 0
reg [ORIG_Y_SIZE + FRACT_BITS - 1:0]yOrigCntPrev;   //initialize row counter on the original image to 0

reg [ORIG_Y_SIZE - 1:0] rowDiff;
reg readOneRow;
reg readTwoRow;
reg [3:0]readSelectAdvance;
reg computeIncrement;
reg nextRowCalculations;
reg [3:0]remainingRowReads;


always @ (posedge clk) begin
    if (rst | start) begin
             state <= startState;
             requestRow <= 0; 
             requestCol<=0; 
             writeSelect <=0;
             readSelect <=0;
             writeEnable <=0;
             readyForRead <= 0;
             yOrigCnt <= 0;
             yOrigCntPrev <= 0;
             readTwoRow<=0;
             readOneRow <=0;
             computeIncrement<=0;
             forceRead <=0;
    end
    else begin
        case(state)
            startState: begin
                if (dInValid & writeEnable) begin
                    //done reading input row
                    if (requestCol == ORIGRESX-1) begin
                        //y and x counters are full, done reading input row
                        if (requestRow == NUMROWSTOSTORE-1) begin
                            state <= afterStartState;
                            readyForRead <= 1;
                        end
                        else begin //incement request row counter and write address only if not NUMROWSTOREAD-1 rows are read
                            writeSelect <= writeSelect + 1;
                            requestRow <= requestRow + 1;   
                        end
                        //x counter is full, reset col counter counter
                        requestCol <= 0;
                        writeEnable <=0;                    
                    end
                    
                    //read input, not done reading input row
                    else begin
                        requestCol <= requestCol + 1;
                    end
                end
                
                else if (dInValid)
                    writeEnable <=1;    
                else
                    writeEnable <=0;       
            end
            
            afterStartState: begin
                readyForRead <= 0;
                state <= incrCompState;
            end
            
            incrCompState: begin //compute the output px location on the input image, and store the previous one
                yOrigCntPrev <= yOrigCnt;
                yOrigCnt <= yOrigCnt + yScale;
                state <= rowDiffCalc;
                readyForRead <= 0;
            end
            
            rowDiffCalc: begin //calculate the difference between the previous and the current px location
                rowDiff <= yOrigCnt[ORIG_Y_SIZE + FRACT_BITS - 1:FRACT_BITS] - yOrigCntPrev[ORIG_Y_SIZE + FRACT_BITS - 1:FRACT_BITS];
                state <= nextRowCalcState;
            end
            
            nextRowCalcState: begin
                if (rowDiff ==0) begin //if there was no difference, row writing is automatically completed
                    writeEnable <=0;
                    //readyForRead <=1;
                    //readOneRow <=0;
                    //readTwoRow<=0;
                    readSelectAdvance <=0;
                    state <= finishedState;
                end
                else if (rowDiff < NUMROWSTOSTORE) begin
                    writeSelect <= writeSelect + 1;
                    requestRow <= requestRow + 1;
                    remainingRowReads <= rowDiff-1;
                    writeEnable <=1;
                    readSelectAdvance <= rowDiff;
                    state <= procState;
                end
                else begin
                    writeSelect <= writeSelect + 1;
                    requestRow <= requestRow + rowDiff - NUMROWSTOSTORE;
                    remainingRowReads <= NUMROWSTOSTORE-1;
                    writeEnable <=1;
                    readSelectAdvance <=NUMROWSTOSTORE;
                    state <= procState;
                end
            end
            
            procState: begin //after reading the first two rows, we are here
                //begin counting the rows of the original image
                if (dInValid & writeEnable) begin
                    if (requestCol == ORIGRESX-1) begin
                        // only x counter is full, reset x counter, incement y counter
                        requestCol <= 0;
                        writeEnable <=0;
                        
                        if (remainingRowReads > 0) begin
                            requestRow <= requestRow + 1;
                            writeSelect <= writeSelect + 1;
                            remainingRowReads <= remainingRowReads - 1;
                        end
                        else begin
                            state <= finishedState;
                        end
                    end
                    else
                        requestCol <= requestCol + 1;//no counter is full, incement x 
                end 
                if (dInValid) begin
                    writeEnable <=1;
                end
            end
            
            finishedState: begin
                if (doneProcessing) begin
                    readyForRead<=1;
                    readSelect <= readSelect + readSelectAdvance;
                    readSelectAdvance <=0;
                    state <= incrCompState;
                    if (requestRow == ORIGRESY-1) begin
                        forceRead <= 1;
                        state <= finishedImageState;
                    end
                end
            end
            
            finishedImageState: begin
                forceRead <= 1;
            end
        endcase
    end
end



endmodule
