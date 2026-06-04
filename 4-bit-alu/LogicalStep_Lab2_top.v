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
    wire [3:0] disp_A, disp_B;   // values fed to the two 7-seg decoders

    // split the 8 switches into two 4-bit operands
    assign hex_A = sw[3:0];
    assign hex_B = sw[7:4];

    // module instantiations
    full_adder_4bit u6 (
        .input_A   (hex_A),
        .input_B   (hex_B),
        .carry_in  (1'b0),
        .hex_sum   (hex_sum),
        .carry_out (carry)
    );

    // display mux network: pb[2] = 0 shows the operands, pb[2] = 1 shows the adder result
    mux_4bit_2_to_1 u7 (
        .din_A    (hex_A),            // pb[2] = 0 -> operand A on DIGIT2
        .din_B    (hex_sum),          // pb[2] = 1 -> SUM on DIGIT2
        .selector (pb[2]),
        .dout     (disp_A)
    );

    mux_4bit_2_to_1 u8 (
        .din_A    (hex_B),            // pb[2] = 0 -> operand B on DIGIT1
        .din_B    ({3'b000, carry}),  // pb[2]=1 -> carry padded to 4 bits (match decoder width), shows 0/1 on DIGIT1
        .selector (pb[2]),
        .dout     (disp_B)
    );

    seven_segment u1 (
        .hex      (disp_A),
        .sevenseg (seg7_A)
    );

    seven_segment u2 (
        .hex      (disp_B),
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

    // buttons are active-low (pressed = 0); invert to active-high so pressed = 1 for the selects
    pb_inverters u4 (
        .pbin  (pb_n),
        .pbout (pb)
    );

    logic_proc u5 (
        .logic_in_A (hex_A),
        .logic_in_B (hex_B),
        .select     (pb[1:0]),
        .logic_out  (leds[3:0])
    );

endmodule
