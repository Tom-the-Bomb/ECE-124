// Seven-segment time-division multiplexer: alternately drives the two digits
// from din1/din2 and applies the open-drain levels required by the PCB.
module segment7_mux (
    input            clk,
    input      [6:0] din2,
    input      [6:0] din1,
    output     [6:0] dout,
    output           dig2,
    output           dig1
);
    wire        toggle;
    wire [6:0]  dout_mux;
    wire [6:0]  dout_temp;
    reg  [31:0] count = 32'd0;

    always @(posedge clk)
        count <= count + 1'b1;

    assign toggle = count[10];   // digit-switching rate

    assign dig1 = ~toggle;       // one digit active per toggle phase
    assign dig2 =  toggle;

    assign dout_mux[0] = toggle ? din2[0] : din1[0];
    assign dout_mux[1] = toggle ? din2[1] : din1[1];
    assign dout_mux[2] = toggle ? din2[2] : din1[2];
    assign dout_mux[3] = toggle ? din2[3] : din1[3];
    assign dout_mux[4] = toggle ? din2[4] : din1[4];
    assign dout_mux[5] = toggle ? din2[5] : din1[5];
    assign dout_mux[6] = toggle ? din2[6] : din1[6];

    // Open-drain (tristate high) on segments 1, 5, 6 for the LogicalStep PCB
    assign dout_temp[0] = dout_mux[0] ? 1'b1 : 1'b0;
    assign dout_temp[1] = dout_mux[1] ? 1'bz : 1'b0;
    assign dout_temp[2] = dout_mux[2] ? 1'b1 : 1'b0;
    assign dout_temp[3] = dout_mux[3] ? 1'b1 : 1'b0;
    assign dout_temp[4] = dout_mux[4] ? 1'b1 : 1'b0;
    assign dout_temp[5] = dout_mux[5] ? 1'bz : 1'b0;
    assign dout_temp[6] = dout_mux[6] ? 1'bz : 1'b0;

    assign dout = dout_temp;
endmodule
