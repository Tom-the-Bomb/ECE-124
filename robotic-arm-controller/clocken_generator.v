// mode is the boolean input to select the clocking outputs for LogicalStep board OR simulation operation
// GLOBAL CLOCK input is the LogicalStep 50MHz clock input
// clock_en is to be connected to the state mackine and other registers in the pipeline

module clocken_generator #(parameter sim_flag) (
	input  reset,
	input  global_clk,           // Global Clock input used for all register clocking
	output limit_reached,
	output global_clken_source   // output used to periodicaLLY enAblE.
);

	parameter FPGA_DOWNLOAD_CLKEN_COUNT = 32'd10000000,  // decimal counts of 20 ns global clock periods per half time of global clock enable
	          SIMULATION_CLKEN_COUNT    = 32'd16;        // decimal counts of 20 ns global clock period per half time of global clock enable

	reg clken_limit_reached;
	reg strobe, clk_enbl;

	// clk_divider process generates a free-running Clock_enbl signal from the 50 Mhz clk
	always @(posedge global_clk) begin
		reg unsigned [24:0] counter;
		if (reset == 1'b1) begin
			clken_limit_reached = 1'b0;
			counter <= 32'd0;
		end
		else if (reset == 1'b0) begin
			if ((sim_flag == 1'b1) && (counter == SIMULATION_CLKEN_COUNT)) begin
				clken_limit_reached = 1'b1;
				counter <= 32'd0;
			end
			else if ((sim_flag == 1'b1) && (counter != SIMULATION_CLKEN_COUNT)) begin
				clken_limit_reached = 1'b0;
				counter <= counter + 1;
			end
			else if ((sim_flag == 1'b0) && (counter == FPGA_DOWNLOAD_CLKEN_COUNT)) begin
				clken_limit_reached = 1'b1;
				counter <= 32'd0;
			end
			else if ((sim_flag == 1'b0) && (counter != FPGA_DOWNLOAD_CLKEN_COUNT)) begin
				clken_limit_reached = 1'b0;
				counter <= counter + 1;
			end
		end
	end

	// clk_extender is an extra pair of serial registers used to create a single one-cycle enable pulse for the state machine
	always @(posedge global_clk) begin
		if (reset == 1'b1)
			strobe <= 1'b0;
		else if (clken_limit_reached)
			strobe <= ~strobe;
	end

	// clk_extender is an extra pair of serial registers used to create a single one-cycle enable pulse for the state machine
	always @(posedge global_clk) begin
		if (reset == 1'b1)
			clk_enbl <= 1'b0;
		else if (reset != 1'b1)
			clk_enbl <= ~strobe & clken_limit_reached;
	end

//assign global_clken_source = (sim_flag) ? 1'b1 : clk_enbl;
	assign global_clken_source = clk_enbl;
	assign limit_reached = clken_limit_reached;

endmodule
