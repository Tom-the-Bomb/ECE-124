module logic_proc (
    input  [3:0] logic_in_A, logic_in_B,
    input  [1:0] select,
    output [3:0] logic_out
);

    // select: 00=AND  01=OR  10=XOR  11=XNOR
    assign logic_out = (select == 2'b00) ?  (logic_in_A & logic_in_B) :
                       (select == 2'b01) ?  (logic_in_A | logic_in_B) :
                       (select == 2'b10) ?  (logic_in_A ^ logic_in_B) :
                       (select == 2'b11) ? ~(logic_in_A ^ logic_in_B) :
                                             4'b0000;

endmodule
