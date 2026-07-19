// Grappler Controller: Moore state machine
// I/O pins: grappler = pb_n[0], reset = pb_n[3]; grappler_on -> leds[1]
module SM2 (
	input      clock,            // global 50 MHz clock
	input      reset,            // synchronous reset (pb_n[3])
	input      sm_clken,         // state machine clock enable (one global_clken tick)
	input      grappler_enbl,    // from SM1: 1 only when extender fully extended
	input      grappler,         // synchronized GRAPPLER button (pb_n[0])
	output reg grappler_on       // 1 = closed, 0 = open -> leds[1]
);

	localparam OPEN = 2'b00, PRESS_TO_CLOSE = 2'b01, CLOSED = 2'b10, PRESS_TO_OPEN = 2'b11;

	reg [1:0] current_state, next_state;

	// Register section: updates current state with next state (decided in transition section) on each clock tick
	always @(posedge clock) begin
		if (reset)
			current_state <= OPEN;
		else if (sm_clken)
			current_state <= next_state;
	end

	// Transition section: determines next state based on current state and inputs
	// - press selects the action, release toggles the grappler
	always @(*) begin
		case (current_state)
			// grappler open, button not pressed; on press -> button held, on release -> stay open
			// wait for press to close grappler
			OPEN:           next_state = (grappler_enbl && grappler) ? PRESS_TO_CLOSE : OPEN;
			// grappler open, button held; on release -> close grappler, on press -> stay in this state
			// wait for release to commit closing of grappler
			PRESS_TO_CLOSE: next_state = grappler ? PRESS_TO_CLOSE : CLOSED;
			// grappler closed, button not pressed; on press -> button held, on release -> stay closed
			// wait for press to open grappler
			CLOSED:         next_state = (grappler_enbl && grappler) ? PRESS_TO_OPEN : CLOSED;
			// grappler closed, button held; on release -> open grappler, on press -> stay in this state
			// wait for release to commit opening of grappler
			PRESS_TO_OPEN:  next_state = grappler ? PRESS_TO_OPEN : OPEN;
			// undefined state: return to a known state and avoid inferred latches
			default:        next_state = OPEN;
		endcase
	end

	// Decoder section: determines outputs based on current state
	always @(*) begin
		// convention: all outputs default to 0, then each state sets the ones it needs
		grappler_on = 1'b0;
		case (current_state)
			// closed, or holding the button that will open it (not released yet) -> still closed
			CLOSED, PRESS_TO_OPEN: grappler_on = 1'b1;
			default: ;
		endcase
	end

endmodule
