// Single-bit magnitude comparator: compares A, B -> A<B, A==B, A>B.
module Compx1 (
    input  A,
    input  B,
    output A_lt_B,   // A < B
    output A_eq_B,   // A == B
    output A_gt_B    // A > B
);
    assign A_lt_B = ~A &  B;
    assign A_eq_B = ~(A ^ B);
    assign A_gt_B =  A & ~B;
endmodule
