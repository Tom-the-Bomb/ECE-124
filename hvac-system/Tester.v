// On-chip tester for the magnitude comparator. Recomputes input1 vs input2
// and checks the comparator flags (i1eqi2/i1gti2/i1lti2) agree. test_pass is
// asserted only while mc_testmode is active and the comparator is correct.
module Tester (
    input        mc_testmode,
    input        i1eqi2,
    input        i1gti2,
    input        i1lti2,
    input  [3:0] input1,
    input  [3:0] input2,
    output reg   test_pass
);
    reg eq_pass, gt_pass, lt_pass;

    // Every branch assigns all three flags to avoid inferred latches.
    always @(*) begin
        if ((input1 == input2) && (i1eqi2 == 1'b1)) begin
            eq_pass = 1'b1;
            gt_pass = 1'b0;
            lt_pass = 1'b0;
        end
        else if ((input1 > input2) && (i1gti2 == 1'b1)) begin
            eq_pass = 1'b0;
            gt_pass = 1'b1;
            lt_pass = 1'b0;
        end
        else if ((input1 < input2) && (i1lti2 == 1'b1)) begin
            eq_pass = 1'b0;
            gt_pass = 1'b0;
            lt_pass = 1'b1;
        end
        else begin
            eq_pass = 1'b0;
            gt_pass = 1'b0;
            lt_pass = 1'b0;
        end

        test_pass = mc_testmode & (eq_pass | gt_pass | lt_pass);
    end
endmodule
