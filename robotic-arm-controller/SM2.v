// Grappler Controller -- Moore state machine
module SM2 (
	input				clock, reset, sm_clken,
	input				grappler_enbl,			// from SM1: high only when fully extended
	input				grappler,				// synchronized GRAPPLER button (pb_n[0])
	output reg			grappler_on				// 1 = closed, 0 = open -> leds[1]
);

	parameter OPEN = 2'b00, PRESS_CLOSE = 2'b01, CLOSED = 2'b10, PRESS_OPEN = 2'b11;

	reg [1:0] current_state, next_state;

	// Register section
	always @(posedge clock) begin
		if (reset)
			current_state <= OPEN;
		else if (sm_clken)
			current_state <= next_state;
	end

	// Transition section -- press selects the action, release toggles the grappler
	always @(*) begin
		case (current_state)
			OPEN:			next_state = (grappler_enbl && grappler) ? PRESS_CLOSE : OPEN;
			PRESS_CLOSE:	next_state = grappler ? PRESS_CLOSE : CLOSED;
			CLOSED:			next_state = (grappler_enbl && grappler) ? PRESS_OPEN : CLOSED;
			PRESS_OPEN:		next_state = grappler ? PRESS_OPEN : OPEN;
			default:		next_state = OPEN;
		endcase
	end

	// Decoder section
	always @(*) begin
		case (current_state)
			CLOSED, PRESS_OPEN:	grappler_on = 1'b1;
			default:			grappler_on = 1'b0;
		endcase
	end

endmodule
