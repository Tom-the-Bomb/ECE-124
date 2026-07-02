// clk input is the LogicalStep 50MHz clock input
module hvac #(parameter hvac_sim)
(
	input 			clk, run, increase, decrease,
	output  [3:0] 	temp
	);

//
//
wire clk_2hz; 	// this clock is used for when the hvac counter is running on the
					// LogicalStep board. The slow 2Hz clk makes the changes easy to observe.

reg hvac_clock;// this clock is used for when the hvac counter is running .
					// in the Simulator LogicalStep board.
					// The fast 50MHz clk makes the short time for simulation events easier to observe.

reg unsigned [3:0]  cnt = 4'b0111; // variable (reg) hex value used in an always process
											  // Initially set to mid-range.


reg [23:0] digital_counter; // output signal used in an always process and it must be a variable (reg)

// clk_divider process generates a 2Hz Clck from the 50 Mhz clk

always@(posedge clk)

	begin
	reg unsigned [23:0]   counter;

// Synchronously update counter
		counter =  counter + 1;

		digital_counter = counter;
	end

assign clk_2hz = digital_counter[23]; // slow 2Hz clock


always@(*)
	begin
		if (hvac_sim == 1'b1)  		// hvac_sim is a multiplexer select control.
				 hvac_clock =  clk; // fast 50MHz clock
		else
				 hvac_clock =  clk_2hz;	// slow 2Hz clock
	end

always@(posedge(hvac_clock))
	begin

// update the cnt value based on inputs run, increase, decrease and the cn value NOT
// going above decimal 15  or below decimal 0..

		if(run && increase && (cnt != 4'b1111))
				cnt <= cnt + 1'b1;

		else if (run && decrease && (cnt != 4'b0000))
				cnt <= cnt - 1'b1;
	end

assign   temp = cnt;

endmodule



