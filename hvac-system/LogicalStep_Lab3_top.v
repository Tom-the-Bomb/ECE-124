// Uncomment to build a simulation model with the hvac_temp virtual pins;
// comment out for an FPGA download compile.
//`define HVAC_SIM

module LogicalStep_Lab3_top (
    input            clkin_50,
    input      [3:0] pb_n,
    input      [7:0] sw,
    output     [7:0] leds,

`ifdef HVAC_SIM
    output     [3:0] hvac_temp,   // simulation-only virtual pins
`endif

    output     [6:0] seg7_data,
    output           seg7_char1,  // digit1 selector
    output           seg7_char2   // digit2 selector
);

    wire        clk_in;
    wire [3:0]  pb;                 // active-high push buttons
    wire [3:0]  hex_A, hex_B;       // desired temp / vacation temp
    wire [6:0]  seg7_A, seg7_B;     // decoded segment patterns
    wire [3:0]  mux_temp;           // selected target temperature
    wire [3:0]  current_temp;       // HVAC current temperature
    wire        aeqb, agtb, altb;   // comparator: mux_temp vs current_temp
    wire        run, increase, decrease;

    // hvac_sim parameter (and sim-only pin hookup)
`ifdef HVAC_SIM
    assign hvac_temp = current_temp;
    localparam hvac_sim = 1'b1;
`endif
`ifndef HVAC_SIM
    localparam hvac_sim = 1'b0;
`endif

    assign clk_in = clkin_50;
    assign hex_A  = sw[3:0];   // desired temperature
    assign hex_B  = sw[7:4];   // vacation temperature

    // Seven-segment: DIGIT2 = mux_temp, DIGIT1 = current_temp
    SevenSegment U0 (
        .hex     (mux_temp),
        .sevenseg(seg7_A)
    );

    SevenSegment U1 (
        .hex     (current_temp),
        .sevenseg(seg7_B)
    );

    segment7_mux U2 (
        .clk (clk_in),
        .din2(seg7_A), .din1(seg7_B),
        .dout(seg7_data),
        .dig2(seg7_char2), .dig1(seg7_char1)
    );

    // Comparator: mux_temp (A) vs current_temp (B)
    Compx4 U3 (
        .hex_A   (mux_temp),
        .hex_B   (current_temp),
        .out_aeqb(aeqb),
        .out_agtb(agtb),
        .out_altb(altb)
    );

    // Comparator self-test (enabled by pb[2]); result -> leds[7]
    Tester U5 (
        .mc_testmode(pb[2]),
        .i1eqi2(aeqb), .i1gti2(agtb), .i1lti2(altb),
        .input1(hex_A), .input2(current_temp),
        .test_pass(leds[7])
    );

    // Target select: pb[3] (vacation) picks vacation_temp over desired_temp
    mux_2to1_4bit U6 (
        .selector(pb[3]),
        .inp1(hex_A), .inp2(hex_B),
        .muxout(mux_temp)
    );

    PB_Inverters U7 (
        .pbin (pb_n),
        .pbout(pb)
    );

    hvac #(.hvac_sim(hvac_sim)) U4 (
        .clk     (clk_in),
        .run     (run),
        .increase(increase),
        .decrease(decrease),
        .temp    (current_temp)
    );

    // Inputs: door=pb[0] window=pb[1] test=pb[2] vac=pb[3]; indicators leds[0..6]
    Energy_Monitor_Control U8 (
        .door_open(pb[0]), .window_open(pb[1]), .mc_testmode(pb[2]), .vac_mode(pb[3]),
        .i1eqi2(aeqb), .i1gti2(agtb), .i1lti2(altb),

        .furnace_on(leds[0]), .at_temp(leds[1]), .ac_on(leds[2]), .blower_on(leds[3]),
        .window_open_led(leds[4]), .door_open_led(leds[5]), .vacation_led(leds[6]),

        .hvac_run(run), .hvac_increase(increase), .hvac_decrease(decrease)
    );

endmodule
