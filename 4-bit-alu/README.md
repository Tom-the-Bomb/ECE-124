# 4 Bit ALU

A 4-bit ALU for the LogicalStep FPGA board. Adds two switch operands, runs
bitwise logic, and shows results on the LEDs and dual 7-segment display.

## How it works

- Operands: `sw[3:0]` = A, `sw[7:4]` = B. Buttons `pb_n` are active-low, inverted to `pb`.
- `full_adder_4bit` = four ripple-chained `full_adder_1bit` cells -> sum + carry.
- `logic_proc` does AND/OR/XOR/XNOR (picked by `pb[1:0]`) -> `leds[3:0]`.
- `pb[2]` picks the digits: 0 = operands (A, B), 1 = adder (sum, carry).
- Two `seven_segment` decoders feed `segment7_mux`, which time-multiplexes both digits.

## Files

| File | Purpose |
|------|---------|
| `LogicalStep_Lab2_top.v` | Top module / pin wiring |
| `full_adder_4bit.v`, `full_adder_1bit.v` | 4-bit ripple-carry adder |
| `logic_proc.v` | AND/OR/XOR/XNOR logic unit |
| `seven_segment.v` | Hex -> 7-segment decoder |
| `segment7_mux.v` | Two-digit display mux + clock divider |
| `pb_inverters.v` | Active-low button inverter |
| `mux_4bit_2_to_1.v` | Display operand/result select |
