// HVAC temperature unit: 4-bit up/down counter emulating a furnace / AC.
// Starts at mid-scale (0x7) and steps toward the target one count per HVAC
// clock while run is active, saturating at 0x0 and 0xF.
// hvac_sim picks the counter clock: 0 = slow ~2 Hz (board), 1 = 50 MHz (sim).
module hvac #(
    parameter hvac_sim = 1'b0
) (
    input            clk, run, increase, decrease,
    output     [3:0] temp
);
    wire        clk_2hz;
    reg         hvac_clock;
    reg  [3:0]  cnt = 4'b0111;      // temperature, initialised to mid-range
    reg  [23:0] clk_divider = 24'd0;

    // Divide 50 MHz down to ~2 Hz (bit 23 toggles at ~3 Hz)
    always @(posedge clk)
        clk_divider <= clk_divider + 1'b1;

    assign clk_2hz = clk_divider[23];

    // Fast clk for simulation, slow clk_2hz on the board
    always @(*)
        hvac_clock = hvac_sim ? clk : clk_2hz;

    // Step toward target, holding at the 0/15 limits
    always @(posedge hvac_clock) begin
        if (run && increase && (cnt != 4'b1111))
            cnt <= cnt + 1'b1;
        else if (run && decrease && (cnt != 4'b0000))
            cnt <= cnt - 1'b1;
    end

    assign temp = cnt;
endmodule
