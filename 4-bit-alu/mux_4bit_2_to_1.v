module mux_4bit_2_to_1 (
    input  [3:0] din_A, din_B,
    input        selector,
    output [3:0] dout
);

    assign dout = (selector == 1'b0) ? din_A : din_B;

endmodule
