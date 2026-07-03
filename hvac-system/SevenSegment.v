// Hex-to-seven-segment decoder. Maps a 4-bit value to segment bits GFEDCBA
// (a segment is on when its bit is 1). Segment layout:
//
//     +-- a --+
//     f       b
//     +-- g --+
//     e       c
//     +-- d --+
//
module SevenSegment (
    input  [3:0] hex,
    output [6:0] sevenseg    // GFEDCBA
);
    assign sevenseg = (hex == 4'h0) ? 7'b0111111 :
                      (hex == 4'h1) ? 7'b0000110 :
                      (hex == 4'h2) ? 7'b1011011 :
                      (hex == 4'h3) ? 7'b1001111 :
                      (hex == 4'h4) ? 7'b1100110 :
                      (hex == 4'h5) ? 7'b1101101 :
                      (hex == 4'h6) ? 7'b1111101 :
                      (hex == 4'h7) ? 7'b0000111 :
                      (hex == 4'h8) ? 7'b1111111 :
                      (hex == 4'h9) ? 7'b1101111 :
                      (hex == 4'hA) ? 7'b1110111 :
                      (hex == 4'hB) ? 7'b1111100 :
                      (hex == 4'hC) ? 7'b1011000 :
                      (hex == 4'hD) ? 7'b1011110 :
                      (hex == 4'hE) ? 7'b1111001 :
                      (hex == 4'hF) ? 7'b1110001 :
                                      7'b0000000;  // blank
endmodule
