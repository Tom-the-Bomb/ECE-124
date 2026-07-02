
module PB_Inverters (
 	input [3:0]	pbin,
	output [3:0] pbout
);


assign pbout = ~(pbin);

endmodule
