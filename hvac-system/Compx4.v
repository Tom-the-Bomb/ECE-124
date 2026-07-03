// 4-bit magnitude comparator: four Compx1 instances compare each bit pair,
// and the boolean equations combine them (MSB first) into A<B, A==B, A>B.
module comp4x (
    input  [3:0] hex_A,
    input  [3:0] hex_B,
    output       A_lt_B,   // A < B
    output       A_eq_B,   // A == B
    output       A_gt_B    // A > B
);
    wire [3:0] altb, aeqb, agtb;   // per-bit results, indexed 3..0

    Compx1 u3 (
        .A     (hex_A[3]),
        .B     (hex_B[3]),
        .A_lt_B(altb[3]),
        .A_eq_B(aeqb[3]),
        .A_gt_B(agtb[3])
    );

    Compx1 u2 (
        .A     (hex_A[2]),
        .B     (hex_B[2]),
        .A_lt_B(altb[2]),
        .A_eq_B(aeqb[2]),
        .A_gt_B(agtb[2])
    );

    Compx1 u1 (
        .A     (hex_A[1]),
        .B     (hex_B[1]),
        .A_lt_B(altb[1]),
        .A_eq_B(aeqb[1]),
        .A_gt_B(agtb[1])
    );

    Compx1 u0 (
        .A     (hex_A[0]),
        .B     (hex_B[0]),
        .A_lt_B(altb[0]),
        .A_eq_B(aeqb[0]),
        .A_gt_B(agtb[0])
    );

    // Highest differing bit decides the result; upper bits must be equal first.
    assign A_lt_B = altb[3]
                  | (aeqb[3] & altb[2])
                  | (aeqb[3] & aeqb[2] & altb[1])
                  | (aeqb[3] & aeqb[2] & aeqb[1] & altb[0]);

    assign A_eq_B = aeqb[3] & aeqb[2] & aeqb[1] & aeqb[0];

    assign A_gt_B = agtb[3]
                  | (aeqb[3] & agtb[2])
                  | (aeqb[3] & aeqb[2] & agtb[1])
                  | (aeqb[3] & aeqb[2] & aeqb[1] & agtb[0]);
endmodule
