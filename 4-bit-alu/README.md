# 4 Bit ALU

A 4-bit ALU for the LogicalStep FPGA board: adds two operands and runs bitwise
logic on them, with results on the LEDs and two 7-segment digits.

## How it works

- **Inputs** — `sw[3:0]` = A, `sw[7:4]` = B; pushbuttons `pb_n` are active-low and inverted to `pb` by `pb_inverters`.
- **Add** — `full_adder_4bit` (four `full_adder_1bit` cells, ripple carry) computes `A + B` -> 4-bit sum + carry.
- **Logic** — `logic_proc` uses `pb[1:0]` to select AND/OR/XOR/XNOR of A and B -> `leds[3:0]`.
- **Display select** — `pb[2]` drives two `mux_4bit_2_to_1` blocks: `pb[2]=0` shows the operands (A on DIGIT2, B on DIGIT1), `pb[2]=1` shows the adder result (SUM on DIGIT2, `{3'b000,carry}` on DIGIT1).
- **Display** — two `seven_segment` decoders convert the selected values to segment patterns; `segment7_mux` time-multiplexes them onto the two digits using a clock divider.
- **Top** — `LogicalStep_Lab2_top` wires it all to the board pins (name fixed by the lab's `.tcl` pin assignments).

## Files

| File                                     | Purpose                               |
| ---------------------------------------- | ------------------------------------- |
| `LogicalStep_Lab2_top.v`                 | Top module / pin wiring               |
| `full_adder_4bit.v`, `full_adder_1bit.v` | 4-bit ripple-carry adder              |
| `logic_proc.v`                           | AND/OR/XOR/XNOR logic unit            |
| `seven_segment.v`                        | Hex -> 7-segment decoder              |
| `segment7_mux.v`                         | Two-digit display mux + clock divider |
| `pb_inverters.v`                         | Active-low button inverter            |
| `mux_4bit_2_to_1.v`                      | 4-bit 2:1 mux (display operand/result select) |
