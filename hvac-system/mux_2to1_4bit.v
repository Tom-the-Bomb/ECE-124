module mux_2to1_4bit (
    input        selector,
    input  [3:0] inp1, inp2,
    output [3:0] muxout
);
    assign muxout = selector ? inp2 : inp1;
endmodule