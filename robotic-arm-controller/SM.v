// X/Y Motion Controller: Moore state machine
module SM (
	input      clock,             // global 50 MHz clock
	input      reset,             // reset everything
	input      sm_clken,          // state machine clock enable (1 tick per 400 ms)
	input      motion,            // synchronized MOTION button (pb_n[2])
	input      extended,          // from SM1: 1 when extender not fully retracted
	input      x_eq,              // X position == captured target (from Compx4)
	input      x_lt,              // X position <  captured target
	input      x_gt,              // X position >  captured target (unused: direction needs only x_lt)
	input      y_eq,              // Y position == captured target (from Compx4)
	input      y_lt,              // Y position <  captured target
	input      y_gt,              // Y position >  captured target (unused)
	output reg capture_enable,    // load pulse for the X/Y target registers
	output reg x_cnt_en,          // X counter enable
	output reg x_cnt_up1_dwn0,    // X counter direction: 1 = up, 0 = down
	output reg y_cnt_en,          // Y counter enable
	output reg y_cnt_up1_dwn0,    // Y counter direction: 1 = up, 0 = down
	output reg extender_enbl,     // to SM1: 1 when arm at rest (extender allowed)
	output reg posc_err           // System Fault Error: motion requested while extended -> leds[0]
);

	parameter AT_REST = 2'b00, CAPTURE = 2'b01, MOVING = 2'b10, FAULT = 2'b11;

	reg [1:0] current_state, next_state;

	// Register section: updates current state with next state (decided in transition section) on each clock tick
	always @(posedge clock) begin
		if (reset)
			current_state <= AT_REST;
		else if (sm_clken)
			current_state <= next_state;
	end

	// Transition section: determines next state based on current state and inputs
	// - press captures the target, release starts the move; requesting motion while extended faults
	always @(*) begin
		case (current_state)
			// at rest, waiting for a motion press
			// press while extended -> fault; press while retracted -> capture; else stay
			AT_REST: if (motion && extended) next_state = FAULT;
			         else if (motion)        next_state = CAPTURE;
			         else                    next_state = AT_REST;
			// target captured, button held; on release -> start moving, on hold -> stay
			// wait for release to begin the move
			CAPTURE: next_state = motion ? CAPTURE : MOVING;
			// counting toward the target; done once both axes match
			MOVING:  next_state = (x_eq && y_eq) ? AT_REST : MOVING;
			// fault latched; clears only once fully retracted and the button is released
			FAULT:   next_state = (!extended && !motion) ? AT_REST : FAULT;
			// undefined state: return to a known state and avoid inferred latches
			default: next_state = AT_REST;
		endcase
	end

	// Decoder section: determines outputs based on current state (defaults first to avoid inferred latches)
	always @(*) begin
		capture_enable = 1'b0;
		x_cnt_en       = 1'b0;
		x_cnt_up1_dwn0 = 1'b0;
		y_cnt_en       = 1'b0;
		y_cnt_up1_dwn0 = 1'b0;
		extender_enbl  = 1'b0;
		posc_err       = 1'b0;
		case (current_state)
			// at rest: extender is allowed to operate
			AT_REST: extender_enbl = 1'b1;
			// capture the switch values into the target registers (still at rest)
			CAPTURE: begin
				capture_enable = 1'b1;
				extender_enbl  = 1'b1;
			end
			// count each axis toward its target, stopping the instant it matches
			MOVING: begin
				x_cnt_en       = !x_eq;   // count until X reaches target
				x_cnt_up1_dwn0 = x_lt;    // 1 (up) when below target, else 0 (down)
				y_cnt_en       = !y_eq;
				y_cnt_up1_dwn0 = y_lt;
			end
			// fault active; keep extender allowed so retracting can clear it
			FAULT: begin
				posc_err      = 1'b1;
				extender_enbl = 1'b1;
			end
			default: ;
		endcase
	end

endmodule
