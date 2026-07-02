
module segment7_mux (
   input clk,
	input [6:0] din2, din1,
	output [6:0] dout,
	output dig2, dig1
	);

// internal module signals
	wire toggle;
	wire [6:0] dout_mux;
 	wire [6:0] dout_temp;
	reg  [31:0] count;
  

//  ----------------------------------------------
//  -- CLOCK Divider File
//  ----------------------------------------------  
  	always@(posedge clk)
  	begin 
 			count <= count + 1;
	end 	

	assign toggle = count[10];
 
	assign dig1 = ~(toggle);
	assign dig2 = toggle;
	
	assign	dout_mux[0] = (toggle == 1'b1) ? din2[0] : din1[0];
	assign	dout_mux[1] = (toggle == 1'b1) ? din2[1] : din1[1];
	assign	dout_mux[2] = (toggle == 1'b1) ? din2[2] : din1[2];
	assign	dout_mux[3] = (toggle == 1'b1) ? din2[3] : din1[3];
	assign	dout_mux[4] = (toggle == 1'b1) ? din2[4] : din1[4];
	assign	dout_mux[5] = (toggle == 1'b1) ? din2[5] : din1[5];
	assign	dout_mux[6] = (toggle == 1'b1) ? din2[6] : din1[6];


//	incorporate TRISTATE levels for specific output pins (for LogicalStap PCB design)
	assign	dout_temp[0] = (dout_mux[0] == 1'b1) ? 1'b1:1'b0;
	assign	dout_temp[1] = (dout_mux[1] == 1'b1) ? 1'bz:1'b0; //open drain
	assign	dout_temp[2] = (dout_mux[2] == 1'b1) ? 1'b1:1'b0; 
	assign	dout_temp[3] = (dout_mux[3] == 1'b1) ? 1'b1:1'b0; 
	assign	dout_temp[4] = (dout_mux[4] == 1'b1) ? 1'b1:1'b0; 
	assign	dout_temp[5] = (dout_mux[5] == 1'b1) ? 1'bz:1'b0; //open drain
	assign	dout_temp[6] = (dout_mux[6] == 1'b1) ? 1'bz:1'b0; //open drain
	
	assign dout = dout_temp;
	
endmodule

