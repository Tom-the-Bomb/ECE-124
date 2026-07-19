// Extender Controller: Moore state machine
// I/O pins: extender = pb_n[1], reset = pb_n[3]; extender position -> leds[5:2]
module SM1 (
	input      clock,              // global 50 MHz clock
	input      reset,              // synchronous reset (pb_n[3])
	input      sm_clken,           // state machine clock enable (one global_clken tick)
	input      extender_enbl,      // from SM: 1 when arm at rest (extender allowed)
	input      extender,           // synchronized EXTENDER button (pb_n[1])
	input      [3:0] extender_pos, // current position from Bidir_shift_reg (-> leds[5:2])
	output reg extender_in_motion, // shift enable to Bidir_shift_reg
	output reg extender_dir,       // 1 = extend, 0 = retract
	output reg extended,           // to SM: 1 whenever not fully retracted
	output reg grappler_enbl       // to SM2: 1 only when fully extended
);

	parameter RETRACTED        = 3'b000,
	          PRESS_TO_EXTEND  = 3'b001,
	          EXTENDING        = 3'b010,
	          EXTENDED         = 3'b011,
	          PRESS_TO_RETRACT = 3'b100,
	          RETRACTING       = 3'b101;

	reg [2:0] current_state, next_state;

	// Register section: updates current state with next state (decided in transition section) on each clock tick
	always @(posedge clock) begin
		if (reset)
			current_state <= RETRACTED;
		else if (sm_clken)
			current_state <= next_state;
	end

	// Transition section: determines next state based on current state and inputs
	// - press selects the direction, release starts the motion, which runs to the end stop
	always @(*) begin
		case (current_state)
			// retracted, button not pressed; on press -> button held, on release -> stay retracted
			// wait for press to begin extending
			RETRACTED:        next_state = (extender_enbl && extender) ? PRESS_TO_EXTEND : RETRACTED;
			// retracted, button held; on release -> start extending, on press -> stay in this state
			// wait for release to commit the extend
			PRESS_TO_EXTEND:  next_state = extender ? PRESS_TO_EXTEND : EXTENDING;
			// shifting outward one step per tick; done once fully extended (1111)
			EXTENDING:        next_state = (extender_pos == 4'b1111) ? EXTENDED : EXTENDING;
			// extended, button not pressed; on press -> button held, on release -> stay extended
			// wait for press to begin retracting
			EXTENDED:         next_state = (extender_enbl && extender) ? PRESS_TO_RETRACT : EXTENDED;
			// extended, button held; on release -> start retracting, on press -> stay in this state
			// wait for release to commit the retract
			PRESS_TO_RETRACT: next_state = extender ? PRESS_TO_RETRACT : RETRACTING;
			// shifting inward one step per tick; done once fully retracted (0000)
			RETRACTING:       next_state = (extender_pos == 4'b0000) ? RETRACTED : RETRACTING;
			// undefined state: return to a known state and avoid inferred latches
			default:          next_state = RETRACTED;
		endcase
	end

	// Decoder section: determines outputs based on current state (defaults first to avoid inferred latches)
	always @(*) begin
		extender_in_motion = 1'b0;
		extender_dir       = 1'b0;
		grappler_enbl      = 1'b0;
		extended           = (extender_pos != 4'b0000);   // 1 whenever not fully retracted (from position, not state)
		case (current_state)
			// drive the shift register rightward
			EXTENDING: begin
				extender_in_motion = 1'b1;
				extender_dir       = 1'b1;
			end
			// drive the shift register leftward
			RETRACTING: begin
				extender_in_motion = 1'b1;
				extender_dir       = 1'b0;
			end
			// fully extended or extended and waiting for retraction button release => commit (not retracting yet) -> grappler may operate
			EXTENDED, PRESS_TO_RETRACT: grappler_enbl = 1'b1;
			default: ;
		endcase
	end

endmodule
