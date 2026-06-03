module full_adder_4bit (
    input  [3:0] bus0,
    input  [3:0] bus1,
    input        cin,
    output [3:0] hex_sum,
    output       carry_out
);

    wire carry_out0, carry_out1, carry_out2;

    // bit 0 (LSB)
    full_adder_1bit fa0 (
        .input_A   (bus0[0]),
        .input_B   (bus1[0]),
        .carry_in  (cin),
        .carry_out (carry_out0),
        .sum_out   (hex_sum[0])
    );

    // bit 1
    full_adder_1bit fa1 (
        .input_A   (bus0[1]),
        .input_B   (bus1[1]),
        .carry_in  (carry_out0),
        .carry_out (carry_out1),
        .sum_out   (hex_sum[1])
    );

    // bit 2
    full_adder_1bit fa2 (
        .input_A   (bus0[2]),
        .input_B   (bus1[2]),
        .carry_in  (carry_out1),
        .carry_out (carry_out2),
        .sum_out   (hex_sum[2])
    );

    // bit 3 (MSB)
    full_adder_1bit fa3 (
        .input_A   (bus0[3]),
        .input_B   (bus1[3]),
        .carry_in  (carry_out2),
        .carry_out (carry_out),
        .sum_out   (hex_sum[3])
    );

endmodule
