//`define HVAC_SIM


module LogicalStep_Lab3_top (
	input 			clkin_50,
	input 	[3:0] pb_n,
 	input 	[7:0]	sw,
   output	[7:0] leds,

	`ifdef HVAC_SIM
		output [3:0] hvac_temp,
	`endif

   output 	[6:0]	seg7_data, // 7-bit outputs to a 7-segment
	output 			seg7_char1,// seg7 digit1 selector
	output			seg7_char2 // seg7 digit2 selector
);

// INTERNAL SIGNALS USED IN THE DESIGN

// declarations associated with the global clock,  push-buttons and switches
wire 			clk_in;
wire [3:0]	pb, hex_A, hex_B;

// declarations associated with the seg7 signals
wire [6:0]	seg7_A, seg7_B;


//-------------------------------------------------------------------
// Here the circuit begins

// hookup up the clock and switches
assign clk_in = clkin_50;
assign hex_A = sw[3:0];
assign hex_B = sw[7:4];

// hookup to hex signals to the 7seg decoders (you may use your decoders from Lab2)
//SevenSegment  U0 (
//.hex (hex_A), .sevenseg (seg7_A)
//);
//SevenSegment U1 (
//.hex (hex_B), .sevenseg (seg7_B)
//);

// hookup to seven_segmnent_mux function
segment7_mux U2 (
.clk (clk_in), .din2 (seg7_A), .din1 (seg7_B), .dout (seg7_data), .dig2 (seg7_char2), .dig1 (seg7_char1)
);

//--------------------------------------------------------------------
// PART A build
wire aeqb, agtb, altb;

//Compx4 U3 (
//	.hex_A (hex_A),
//	.hex_B (hex_B),
//	.out_altb (altb),
//	.out_aeqb (aeqb),
//	.out_agtb (agtb)
//);

//assign leds[0] = altb;
//assign leds[1] = aeqb;
//assign leds[2] = agtb;

//--------------------------------------------------------------------
// Part B build
wire [3:0] current_temp;

SevenSegment U1 (
	.hex(current_temp),
	.sevenseg(seg7_B),
);

//Compx4 U3 (
//	.hex_A (hex_A),
//	.hex_B (current_temp),
//	.out_aeqb (aeqb),
//	.out_agtb (agtb),
//	.out_altb (altb),
//);

//hvac #(.hvac_sim(1'b0)) U4 (
//	.clk(clkin_50),
//	.run(1'b1),
//	.increase(agtb),
//	.decrease(altb),
//	.temp(current_temp),
//);
//
//Tester U5 (
//	.mc_testmode (1'b1),
//	.i1eqi2(aeqb),.i1gti2(agtb),.i1lti2(altb),
//	.input1 (hex_A),.input2 (current_temp),
//	.test_pass (leds[7])
//);

//--------------------------------------------------------------------
// Part C build

// COMMENT OUT the SEVENSEGMENT U0 MODULE in the starter part of the file AND USE THIS ONE FOR PART C
SevenSegment U0
    (.hex (mux_temp), .sevenseg (seg7_A)
);

////COMMENT OUT the hvac module in the PART B section
//hvac #(.hvac_sim (hvac_sim)) U4 (
//    .clk (clk_in), .run (1'b1), .increase (agtb), .decrease (altb),
//    .temp (current_temp)
//);

`ifdef HVAC_SIM
    assign hvac_temp = current_temp;
    localparam hvac_sim = 1'b1;
`endif
`ifndef HVAC_SIM
    localparam hvac_sim = 1'b0;
`endif

// COMMENT OUT the comp4x U3 MODULE in the PART B Build section AND USE THIS ONE FOR PART D
Compx4 U3 (
    .hex_A (mux_temp), .hex_B (current_temp),
    .out_aeqb (aeqb), .out_agtb (agtb), .out_altb (altb)
);

////COMMENT OUT the Tester U5 module in the PART B section
Tester U5 (
    .mc_testmode (pb[3]),
    .i1eqi2(aeqb), .i1gti2(agtb), .i1lti2(altb),
    .input1 (hex_A), .input2 (current_temp),
    .test_pass (leds[7])
);

wire [3:0] mux_temp;

// add your input multiplexer here
mux_2to1_4bit U6 (
    .selector (pb[3]),
    .inp1(hex_A), .inp2 (hex_B),
    .muxout (mux_temp)
);

//wire [3:0] pb;

// add your PB inverter block here
PB_Inverters U7 (
    .pbin (pb_n),
    .pbout (pb)
);

//--------------------------------------------------------------------
// Part D build

// COMMENT OUT ASSIGN STATEMENTS IN PART A FOR leds[2], leds[1], leds[0]

//COMMENT OUT the hvac module in the PART C section
hvac #(.hvac_sim (hvac_sim)) U4 (
    .clk (clk_in), .run (run), .increase (increase), .decrease (decrease),
    .temp (current_temp)
);

//add declarations associated with the Energy Monitor Control block signals
wire  increase, decrease, run;

//add Energy Monitor Control block here
Energy_Monitor_Control U8 (
    .door_open(pb[0]), .window_open(pb[1]), .mc_testmode(pb[2]), .vac_mode(pb[3]),
    .i1eqi2(aeqb), .i1gti2(agtb), .i1lti2(altb),

    .blower_on(leds[3]), .ac_on(leds[2]), .at_temp(leds[1]), .furnace_on(leds[0]),
    .HVAC_run(run), .HVAC_increase(increase), .HVAC_decrease (decrease),
    .vacation_led(leds[6]), .door_open_led(leds[5]), .window_open_led(leds[4])
);

endmodule
