module Compx1 (
	input in_a,
	input in_b,
	output out_lt,
	output out_eq,
	output out_gt
);
	assign out_lt = ~in_a & in_b;
	assign out_eq = ~(in_a ^ in_b);
	assign out_gt = in_a & ~in_b;
endmodule
