`timescale 1ns / 1ps


module test(

    );
      
reg clk = 1;
always #5
   clk <= ~clk;
     
    //QS1.10 ->12 bits
reg signed [11:0]phase = 12'b111100111101;
//QS8.0 -> 9 bits

reg signed [8:0] data_sign = {1'b0,8'd255};
reg signed [8:0] data2_sign = {1'b0,8'd1};
//QS10.10 -> 21 bits
reg signed [8 + 12:0] mult;
reg signed [8 + 12:0] mult2;

always @(posedge clk) begin
    mult <= phase*{1'b0,8'd255};
    mult2 <= phase*{1'b0,8'd1};
   end

endmodule
