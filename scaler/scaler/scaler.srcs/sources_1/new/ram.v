`timescale 1ns / 1ps


module ram#(
	parameter DATA_WIDTH = 8,
	parameter ADDRESS_WIDTH = 8
)(
	input wire [(DATA_WIDTH-1):0] dataA, dataB,
	input wire [(ADDRESS_WIDTH-1):0] addrA, addrB,
	input wire weA, weB, clk,
	output reg [(DATA_WIDTH-1):0] outA, outB
);

	reg [DATA_WIDTH-1:0] ram[2**ADDRESS_WIDTH-1:0];

	//Port A
	always @ (posedge clk) begin
		if (weA) begin
			ram[addrA] <= dataA;
			outA <= dataA;
		end
		else
			outA <= ram[addrA];
	end 

	//Port B
	always @ (posedge clk) begin
		if (weB) begin
			ram[addrB] <= dataB;
			outB <= dataB;
		end
		else
			outB <= ram[addrB];
	end

endmodule

