module logic_proc (
    input  [3:0] logic_in0, logic_in1,
    input  [1:0] select,
    output [3:0] logic_out
);

    assign logic_out = (select == 2'b00) ?  (logic_in0 & logic_in1) :
                       (select == 2'b01) ?  (logic_in0 | logic_in1) :
                       (select == 2'b10) ?  (logic_in0 ^ logic_in1) :
                       (select == 2'b11) ? ~(logic_in0 ^ logic_in1) :
                                             4'b0000;

endmodule
