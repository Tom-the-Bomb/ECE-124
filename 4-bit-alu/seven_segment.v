module seven_segment (
    input  [3:0] hex,        // the 4-bit data to be displayed
    output [6:0] sevenseg    // 7-bit output to a 7-segment display
);

    // The following statements convert a 4-bit input (hex) into a pattern of 7 bits.
    // Each segment turns on when it is '1', otherwise '0'.
    // Seven-segment display map:
    //
    //         +---- a -----+
    //         |            |
    //         f            b
    //         |            |
    //         +---- g -----+
    //         |            |
    //         e            c
    //         |            |
    //         +---- d -----+
    //
    //                                 hex bits      sevenseg
    //                                  3210          GFEDCBA
    assign sevenseg = (hex == 4'b0000) ? 7'b0111111 :
                      (hex == 4'b0001) ? 7'b0000110 :
                      (hex == 4'b0010) ? 7'b1011011 :
                      (hex == 4'b0011) ? 7'b1001111 :
                      (hex == 4'b0100) ? 7'b1100110 :
                      (hex == 4'b0101) ? 7'b1101101 :
                      (hex == 4'b0110) ? 7'b1111101 :
                      (hex == 4'b0111) ? 7'b0000111 :
                      (hex == 4'b1000) ? 7'b1111111 :
                      (hex == 4'b1001) ? 7'b1101111 :
                      (hex == 4'b1010) ? 7'b1110111 :
                      (hex == 4'b1011) ? 7'b1111100 :
                      (hex == 4'b1100) ? 7'b1011000 :
                      (hex == 4'b1101) ? 7'b1011110 :
                      (hex == 4'b1110) ? 7'b1111001 :
                      (hex == 4'b1111) ? 7'b1110001 :
                                         7'b0000000;  // for other values

endmodule
