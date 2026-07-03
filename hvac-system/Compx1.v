// Single-bit magnitude comparator: compares in_a, in_b -> A<B, A==B, A>B.
module Compx1 (
    input  in_a,
    input  in_b,
    output out_lt,   // A < B
    output out_eq,   // A == B
    output out_gt    // A > B
);
    assign out_lt = ~in_a &  in_b;
    assign out_eq = ~(in_a ^ in_b);
    assign out_gt =  in_a & ~in_b;
endmodule
