
module Tester (
 	input 		mc_testmode,
   input 		i1eqi2,i1gti2,i1lti2,
	input [3:0]	input1, input2,

	output reg	test_pass
	);

reg	eq_pass, gt_pass, lt_pass;

always@(*)

begin

		if ((input1 == input2) && (i1eqi2 == 1'b1)) begin
		eq_pass = 1'b1;
		gt_pass = 1'b0;
		lt_pass = 1'b0;
		end
		else if((input1 > input2) && (i1gti2 == 1'b1)) begin
		gt_pass = 1'b1;
		eq_pass = 1'b0;
		lt_pass = 1'b0;
		end
		else if((input1 < input2) && (i1lti2 == 1'b1)) begin
		lt_pass = 1'b1;
		eq_pass = 1'b0;
		gt_pass = 1'b0;
		end

		else begin
		eq_pass = 1'b0;
		gt_pass = 1'b0;
		lt_pass = 1'b0;
		end

		test_pass = mc_testmode & (eq_pass | gt_pass | lt_pass);

end

endmodule
