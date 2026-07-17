module Bidir_shift_reg (
	input        clock,
	input        reset,
	input        extender_clken,
	input        extender_enbl,
	input        extender_dir,
	output [3:0] reg_bits
);

	reg [3:0] sreg;

	always @(posedge clock) begin
		if (reset == 1'b1)
			sreg <= 4'b0000;
		else if ((extender_clken) && (extender_enbl == 1'b1))
			if (extender_dir == 1'b1)           // TRUE for RIGHT shift
				sreg <= {1'b1, sreg[3:1]};      // right-shift of bits
			else if (extender_dir == 1'b0)
				sreg <= {sreg[2:0], 1'b0};      // left-shift of bits
	end

	assign reg_bits = sreg;

endmodule
