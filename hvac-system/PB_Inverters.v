// Inverts the active-low push buttons (pb_n) into active-high signals (pb).
module PB_Inverters (
    input  [3:0] pbin,
    output [3:0] pbout
);
    assign pbout = ~pbin;
endmodule
