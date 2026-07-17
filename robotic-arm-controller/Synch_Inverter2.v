module Synch_Inverter2 (
	input       sync_clk,
	input [3:0] pb_n,
	output      sync_reset, sync_motion, sync_extender, sync_grappler
);

	reg [1:0] stages_pb0, stages_pb1, stages_pb2, stages_pb3;

	always @(posedge sync_clk) begin
		stages_pb3[1:0] <= {stages_pb3[0], ~(pb_n[3])};
		stages_pb2[1:0] <= {stages_pb2[0], ~(pb_n[2])};
		stages_pb1[1:0] <= {stages_pb1[0], ~(pb_n[1])};
		stages_pb0[1:0] <= {stages_pb0[0], ~(pb_n[0])};
	end

	assign sync_reset    = stages_pb3[1] & stages_pb3[0];
	assign sync_motion   = stages_pb2[1] & stages_pb2[0];
	assign sync_extender = stages_pb1[1] & stages_pb1[0];
	assign sync_grappler = stages_pb0[1] & stages_pb0[0];

//	assign sync_reset    = stages_pb3[1];
//	assign sync_motion   = stages_pb2[1];
//	assign sync_extender = stages_pb1[1];
//	assign sync_grappler = stages_pb0[1];

endmodule
