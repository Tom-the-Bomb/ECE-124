// 4-bit magnitude comparator: four Compx1 instances compare each bit pair,
// and the boolean equations combine them (MSB first) into A<B, A==B, A>B.
module Compx4 (
    input  [3:0] hex_A,
    input  [3:0] hex_B,
    output       out_altb,   // A < B
    output       out_aeqb,   // A == B
    output       out_agtb    // A > B
);
    wire [3:0] altb, aeqb, agtb;   // per-bit results, indexed 3..0

    Compx1 u3 (
        .in_a  (hex_A[3]),
        .in_b  (hex_B[3]),
        .out_lt(altb[3]),
        .out_eq(aeqb[3]),
        .out_gt(agtb[3])
    );

    Compx1 u2 (
        .in_a  (hex_A[2]),
        .in_b  (hex_B[2]),
        .out_lt(altb[2]),
        .out_eq(aeqb[2]),
        .out_gt(agtb[2])
    );

    Compx1 u1 (
        .in_a  (hex_A[1]),
        .in_b  (hex_B[1]),
        .out_lt(altb[1]),
        .out_eq(aeqb[1]),
        .out_gt(agtb[1])
    );

    Compx1 u0 (
        .in_a  (hex_A[0]),
        .in_b  (hex_B[0]),
        .out_lt(altb[0]),
        .out_eq(aeqb[0]),
        .out_gt(agtb[0])
    );

    // Highest differing bit decides the result; upper bits must be equal first.
    assign out_altb = altb[3]
                    | (aeqb[3] & altb[2])
                    | (aeqb[3] & aeqb[2] & altb[1])
                    | (aeqb[3] & aeqb[2] & aeqb[1] & altb[0]);

    assign out_aeqb = aeqb[3] & aeqb[2] & aeqb[1] & aeqb[0];

    assign out_agtb = agtb[3]
                    | (aeqb[3] & agtb[2])
                    | (aeqb[3] & aeqb[2] & agtb[1])
                    | (aeqb[3] & aeqb[2] & aeqb[1] & agtb[0]);
endmodule
