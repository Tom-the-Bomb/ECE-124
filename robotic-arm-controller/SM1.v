// Extender Controller -- Moore state machine
module SM1 (
	input				clock, reset, sm_clken,
	input				extender_enbl,			// from SM: extender allowed only at rest
	input				extender,				// synchronized EXTENDER button (pb_n[1])
	input [3:0]			extender_pos,			// current position from Bidir_shift_reg
	output reg			extender_in_motion,		// shift enable to Bidir_shift_reg
	output reg			extender_dir,			// 1 = extend, 0 = retract
	output reg			extended,				// to SM: high whenever not fully retracted
	output reg			grappler_enbl			// to SM2: high only when fully extended
);

	parameter	RETRACTED		= 3'b000,
				PRESS_EXTEND	= 3'b001,
				EXTENDING		= 3'b010,
				EXTENDED		= 3'b011,
				PRESS_RETRACT	= 3'b100,
				RETRACTING		= 3'b101;

	reg [2:0] current_state, next_state;

	// Register section
	always @(posedge clock) begin
		if (reset)
			current_state <= RETRACTED;
		else if (sm_clken)
			current_state <= next_state;
	end

	// Transition section -- press selects the direction, release begins the motion
	always @(*) begin
		case (current_state)
			RETRACTED:		next_state = (extender_enbl && extender) ? PRESS_EXTEND : RETRACTED;
			PRESS_EXTEND:	next_state = extender ? PRESS_EXTEND : EXTENDING;
			EXTENDING:		next_state = (extender_pos == 4'b1111) ? EXTENDED : EXTENDING;
			EXTENDED:		next_state = (extender_enbl && extender) ? PRESS_RETRACT : EXTENDED;
			PRESS_RETRACT:	next_state = extender ? PRESS_RETRACT : RETRACTING;
			RETRACTING:		next_state = (extender_pos == 4'b0000) ? RETRACTED : RETRACTING;
			default:		next_state = RETRACTED;
		endcase
	end

	// Decoder section
	always @(*) begin
		extender_in_motion	= 1'b0;
		extender_dir		= 1'b0;
		grappler_enbl		= 1'b0;
		extended			= (extender_pos != 4'b0000);
		case (current_state)
			EXTENDING:	begin
				extender_in_motion	= 1'b1;
				extender_dir		= 1'b1;
			end
			RETRACTING:	begin
				extender_in_motion	= 1'b1;
				extender_dir		= 1'b0;
			end
			EXTENDED, PRESS_RETRACT:	grappler_enbl = 1'b1;	// grappler only at full extension
			default: ;
		endcase
	end

endmodule
