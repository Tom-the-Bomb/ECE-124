// X/Y Motion Controller -- Moore state machine
module SM (
	input				clock, reset, sm_clken,
	input				motion,					// synchronized MOTION button (pb_n[2])
	input				extended,				// from SM1: extender not fully retracted
	input				x_eq, x_lt, x_gt,		// X position vs captured target
	input				y_eq, y_lt, y_gt,		// Y position vs captured target
	output reg			capture_enable,			// load pulse for the X/Y target registers
	output reg			x_cnt_en, x_cnt_up1_dwn0,
	output reg			y_cnt_en, y_cnt_up1_dwn0,
	output reg			extender_enbl,			// to SM1: extender allowed only at rest
	output reg			posc_err				// system fault -> leds[0]
);

	parameter IDLE = 2'b00, CAPTURE = 2'b01, MOVE = 2'b10, FAULT = 2'b11;

	reg [1:0] current_state, next_state;

	// Register section
	always @(posedge clock) begin
		if (reset)
			current_state <= IDLE;
		else if (sm_clken)
			current_state <= next_state;
	end

	// Transition section
	always @(*) begin
		case (current_state)
			IDLE:		if (motion && extended)	next_state = FAULT;		// move requested while extended
						else if (motion)		next_state = CAPTURE;
						else					next_state = IDLE;
			CAPTURE:	next_state = motion ? CAPTURE : MOVE;			// release starts the move
			MOVE:		next_state = (x_eq && y_eq) ? IDLE : MOVE;		// done when both axes arrive
			FAULT:		next_state = (!extended && !motion) ? IDLE : FAULT;	// locked until fully retracted
			default:	next_state = IDLE;
		endcase
	end

	// Decoder section
	always @(*) begin
		capture_enable		= 1'b0;
		x_cnt_en			= 1'b0;
		x_cnt_up1_dwn0		= 1'b0;
		y_cnt_en			= 1'b0;
		y_cnt_up1_dwn0		= 1'b0;
		extender_enbl		= 1'b0;
		posc_err			= 1'b0;
		case (current_state)
			IDLE:		extender_enbl = 1'b1;
			CAPTURE:	begin
				capture_enable = 1'b1;
				extender_enbl  = 1'b1;
			end
			MOVE:		begin
				x_cnt_en		= !x_eq;		// stop each axis once it reaches target
				x_cnt_up1_dwn0	= x_lt;			// below target -> count up
				y_cnt_en		= !y_eq;
				y_cnt_up1_dwn0	= y_lt;
			end
			FAULT:		begin
				posc_err		= 1'b1;
				extender_enbl	= 1'b1;			// allow retraction to clear the fault
			end
			default: ;
		endcase
	end

endmodule
