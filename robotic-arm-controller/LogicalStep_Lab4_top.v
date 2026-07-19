//`define SIM_FLAG

module LogicalStep_Lab4_top (
	input        clkin_50,
	input  [3:0] pb_n,
	input  [7:0] sw,
	output [7:0] leds,
`ifdef SIM_FLAG
	output [3:0] xreg, yreg,   // (for SIMULATION only)
	output [3:0] xPOS, yPOS,   // (for SIMULATION only)
	output       x_cnt_en_out,
	output       x_comp_gt_out,
	output       x_comp_lt_out,
	output       y_cnt_en_out,
	output       y_comp_gt_out,
	output       y_comp_lt_out,
	output       clock_out,
	output       global_clken_out,
	output       clken_out,
	output       limit_out,
	output       motion_out,
	output       extender_out,
	output       grappler_out,
	output       extended_out,
`endif
	output [6:0] seg7_data,    // 7-bit outputs to a 7-segment display (for LogicalStep only)
	output       seg7_char1,   // seg7 digit1 selector (for LogicalStep only)
	output       seg7_char2    // seg7 digit2 selector (for LogicalStep only)
);

	/////////////////////////////////////////////////////////////////////////////////////////////////
	//////// START of INFRASTRUCTURE FUNCTIONS (CLOCK, CLOCK ENABLE AND SYNC SIGNALS) Section ///////

`ifdef SIM_FLAG
	localparam sim_flag = 1'b1;
`endif
`ifndef SIM_FLAG
	localparam sim_flag = 1'b0;
`endif

	wire global_clk;             // Global Clock input used for all register clocking
	wire clken, global_clken;    // output used to periodicaLLY enAblE.
	wire limit_reached;

	clocken_generator #(.sim_flag (sim_flag)) U1 (
		.reset (reset),
		.global_clk (global_clk),            // Global Clock input used for all register clocking
		.limit_reached (limit_reached),
		.global_clken_source (clken)         // output used to periodicaLLY clock enablE registers.
	);

	wire reset, motion, extender, grappler;

	// invert the ACTIVE_LOW push-button inputs and then filter and synchronize them to the 50 MHz clock
	Synch_Inverter2 U2 (
		.sync_clk (global_clk),
		.pb_n (pb_n),
		.sync_reset (reset),         // (pb_n(3)
		.sync_motion (motion),       // (pb_n(2)
		.sync_extender (extender),   // (pb_n(1)
		.sync_grappler (grappler)    // (pb_n(0)
	);

	// assign a GLOBAL BUFFER for the GLOBAL CLOCK (clkin_50)
	GLOBAL GLOBAL_CLOCK (.in(clkin_50), .out(global_clk));

	// assign a GLOBAL BUFFER for the GLOBAL Clock Enable
	GLOBAL GLOBAL_CLKEN (.in(clken), .out(global_clken));

	///////////////  END of INFRASTRUCTURE Section ///////////////////////
	//////////////////////////////////////////////////////////////////////

	//////////////////////////////////////////////////////////////////////
	///////////////START of X/Y Controller Section ///////////////////////

	wire       x_eq, x_gt, x_lt;
	wire       x_cnt_en, x_cnt_up1_dwn0;
	wire [3:0] x_pos;            // X position
	wire [3:0] x_target;         // X target value from switches
	wire [3:0] x_capt_reg;       // X target capture register

	wire       y_eq, y_gt, y_lt;
	wire       y_cnt_en, y_cnt_up1_dwn0;
	wire [3:0] y_pos;            // y position
	wire [3:0] y_target;         // y target value from switches
	wire [3:0] y_capt_reg;       // y target capture register

	wire       capture_enable;   // Target Co-ordinate Capture enable signal
	wire       posc_err;         // Position Controller Error status bit

	wire [6:0] seg7_x;           // signals for x-position
	wire [6:0] seg7_y;           // signals for y-position

	// State Machine for X/Y Position Controller
	SM U3 (
		.clock (global_clk),
		.reset (reset),
		.sm_clken (global_clken),
		.motion (motion),
		.extended (extended),
		.x_eq (x_eq), .x_lt (x_lt), .x_gt (x_gt),
		.y_eq (y_eq), .y_lt (y_lt), .y_gt (y_gt),
		.capture_enable (capture_enable),
		.x_cnt_en (x_cnt_en), .x_cnt_up1_dwn0 (x_cnt_up1_dwn0),
		.y_cnt_en (y_cnt_en), .y_cnt_up1_dwn0 (y_cnt_up1_dwn0),
		.extender_enbl (extender_enbl),
		.posc_err (posc_err)
	);

	assign x_target = sw[7:4];
	// X-Co-ordinate Position capture register
	REG_4bit U6 (
		.clk (global_clk),
		.reset (reset),
		.load (capture_enable),
		.data (x_target),
		.target_reg (x_capt_reg)
	);

	assign y_target = sw[3:0];
	// X-Co-ordinate Position capture register
	REG_4bit U7 (
		.clk (global_clk),
		.reset (reset),
		.load (capture_enable),
		.data (y_target),
		.target_reg (y_capt_reg)
	);

	// X-Co-ordinate Position counter
	U_D_Bin_Counter4bit U8 (
		.clk (global_clk),
		.global_clken (global_clken),
		.reset (reset),
		.count_en (x_cnt_en),
		.count_up1_dwn0 (x_cnt_up1_dwn0),
		.count (x_pos)
	);

	// Y-Co-ordinate Position counter
	U_D_Bin_Counter4bit U9 (
		.clk (global_clk),
		.reset (reset),
		.global_clken (global_clken),
		.count_en (y_cnt_en),
		.count_up1_dwn0 (y_cnt_up1_dwn0),
		.count (y_pos)
	);

	// hex comparators for x/y position values
	Compx4 U10 (
		.a_hex (x_pos),
		.b_hex (x_capt_reg),
		.a_eq_b (x_eq),
		.a_gt_b (x_gt),
		.a_lt_b (x_lt)
	);

	Compx4 U11 (
		.a_hex (y_pos),
		.b_hex (y_capt_reg),
		.a_eq_b (y_eq),
		.a_gt_b (y_gt),
		.a_lt_b (y_lt)
	);

	// Y Position decoder
	SevenSegment U12 (
		.hex (x_pos),
		.sevenseg (seg7_x)
	);

	// Y Position decoder
	SevenSegment U13 (
		.hex (y_pos),
		.sevenseg (seg7_y)
	);

	// X-Y Position displays
	segment7_mux U14 (
		.clk (global_clk),
		.din2 (seg7_y),
		.din1 (seg7_x),
		.dout (seg7_data),
		.dig2 (seg7_char2),
		.dig1 (seg7_char1)
	);

	// LED outputs for MOTION ERROR (LOCKED) status
	assign leds[0] = posc_err;

	///////////////  END of X/Y Controller Section ///////////////////////
	//////////////////////////////////////////////////////////////////////

	//////////////////////////////////////////////////////////////////////
	/////////////// START of EXTENDER Controller Section /////////////////

	wire       extender_enbl, extender_in_motion;
	wire       extender_dir, extended;   // Extender Control
	wire [3:0] extender_pos;             // Extender extension position to be displayed on leds[7:4]

	// State Machine for Extender Controller
	SM1 U4 (
		.clock (global_clk),
		.reset (reset),
		.sm_clken (global_clken),
		.extender_enbl (extender_enbl),
		.extender (extender),
		.extender_pos (extender_pos),
		.extender_in_motion (extender_in_motion),
		.extender_dir (extender_dir),
		.extended (extended),
		.grappler_enbl (grappler_enbl)
	);

	// Extender Shift Register
	Bidir_shift_reg U15 (
		.clock (global_clk),
		.reset (reset),
		.extender_clken (global_clken),
		.extender_enbl (extender_in_motion),
		.extender_dir (extender_dir),
		.reg_bits (extender_pos)
	);

	// LED outputs for Extender position status
	assign leds[5:2] = extender_pos[3:0];

	///////////////  END of EXTENDER Controller Section //////////////////
	//////////////////////////////////////////////////////////////////////

	//////////////////////////////////////////////////////////////////////
	/////////////// START of GRAPPLER Controller Section /////////////////

	wire grappler_enbl;   // Grappler activation enable
	wire grappler_on;     // Grappler Status bits

	// connect Moore State Machine for Grappler Controller
	SM2 U5 (
		.clock (global_clk),
		.reset (reset),
		.sm_clken (global_clken),
		.grappler_enbl (grappler_enbl),
		.grappler (grappler),
		.grappler_on (grappler_on)
	);

	// LED outputs for Grappler status
	assign leds[1] = grappler_on;

	///////////////  END of GRAPPLER Controller Section //////////////////
	//////////////////////////////////////////////////////////////////////

	// outputs used for simulations only
`ifdef SIM_FLAG
	assign xreg             = x_capt_reg[3:0];
	assign yreg             = y_capt_reg[3:0];
	assign xPOS             = x_pos[3:0];
	assign yPOS             = y_pos[3:0];
	assign x_cnt_en_out     = x_cnt_en;
	assign x_comp_gt_out    = x_gt;
	assign x_comp_lt_out    = x_lt;
	assign y_cnt_en_out     = y_cnt_en;
	assign y_comp_gt_out    = y_gt;
	assign y_comp_lt_out    = y_lt;
	assign clock_out        = global_clk;
	assign global_clken_out = global_clken;
	assign clken_out        = clken;
	assign limit_out        = limit_reached;
	assign motion_out       = motion;
	assign extender_out     = extender;
	assign grappler_out     = grappler;
	assign extended_out     = extended;
`endif
////////////////////////////////////////////////////////////////////////////////////////////////

endmodule
