module LogicalStep_Lab2_top (
    input            rst_n,      // reset in
    input            clkin_50,   // clock in
    input      [7:0] sw,
    input      [3:0] pb_n,

    output     [7:0] leds,
    output     [6:0] seg7_data,
    output           seg7_char1,
    output           seg7_char2
);

    // intermediate signals
    wire [3:0] hex_A, hex_B;
    wire [6:0] seg7_A, seg7_B;
    wire [3:0] pb;
    wire [3:0] hex_sum;
    wire       carry;

    // wire assignments
    assign hex_A = sw[3:0];
    assign hex_B = sw[7:4];

    // module instantiations
    full_adder_4bit u6 (
        .bus0      (hex_A),
        .bus1      (hex_B),
        .cin       (1'b0),
        .hex_sum   (hex_sum),
        .carry_out (carry)
    );

    SevenSegment u1 (
        .hex      (hex_sum),
        .sevenseg (seg7_A)
    );

    SevenSegment u2 (
        .hex      ({3'b000, carry}),
        .sevenseg (seg7_B)
    );

    segment7_mux u3 (
        .clk  (clkin_50),
        .din2 (seg7_A),
        .din1 (seg7_B),
        .dout (seg7_data),
        .dig2 (seg7_char2),
        .dig1 (seg7_char1)
    );

    pb_inverters u4 (
        .pbin  (pb_n),
        .pbout (pb)
    );

    logic_proc u5 (
        .logic_in0 (hex_A),
        .logic_in1 (hex_B),
        .select    (pb[1:0]),
        .logic_out (leds[3:0])
    );

endmodule
