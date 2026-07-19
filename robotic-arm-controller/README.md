# Robotic Arm Controller

A robotic arm controller that drives the arm to an X/Y target set by the switches, extends and retracts a grappler arm, and opens/closes the grappler, with
interlocks so the three actions don't interfere with each other.

Each button is press-hold-release: the press starts the request, and the release commits it. Each functionality is run by a state machine.

## Inputs

- `sw[7:4]` = X target (0–F), `sw[3:0]` = Y target (0–F).
- Buttons are active-low (`pb_n`), inverted, filtered and synchronized to the
  50 MHz clock by `Synch_Inverter2`.

| Button             | Does                                                     |
| ------------------ | -------------------------------------------------------- |
| `pb_n[3]` reset    | resets all registers and state machines                  |
| `pb_n[2]` motion   | press captures X/Y target, release starts the move       |
| `pb_n[1]` extender | toggles extend / retract (only while the arm is stopped) |
| `pb_n[0]` grappler | toggles close / open (only while fully extended)         |

## Outputs

- `DIGIT1` = X position, `DIGIT2` = Y position.

| LED                   | Shows                                               |
| --------------------- | --------------------------------------------------- |
| `leds[0]` posc_err    | fault: motion requested while the extender is out   |
| `leds[1]` grappler_on | 1 = closed, 0 = open                                |
| `leds[5:2]` extender  | position: `0000` retracted -> `1111` fully extended |
| `leds[7:6]`           | spare / diagnostics                                 |

## Locks & edge cases

- **Extender** works only while the arm is stopped (i.e. a press during motion is ignored.)
- **Grappler** works only when the extender is fully extended (`1111`), ignored otherwise.
- **Motion while the extender is out → fault** (`leds[0]`): no move, latched until the extender is fully retracted _and_ the button is released.
- Target is captured on **press** and **locked once moving** (changing switches mid-move does nothing).
- Axes stop **independently**; asking to move to the current position does nothing.
- **One button at a time**; hold ~1 s so the press overlaps a clock tick.
- **Reset** (`pb_n[3]`) returns everything to its start state.

## How it works

`SM` captures the target into the two `REG_4bit` registers on the motion press,
then on release counts the `U_D_Bin_Counter4bit` position counters up or down
until `Compx4` says each axis matches. Axes stop independently, so whichever
arrives first stays put while the other keeps going.

`SM1` shifts `Bidir_shift_reg` one step per clock enable to extend (`0000` ->
`1000` -> `1100` -> `1110` -> `1111`) or retract back to `0000`. `SM2` toggles the
grappler open/closed. The three machines gate each other: `SM` enables the
extender (`extender_enbl`) only at rest, `SM1` enables the grappler
(`grappler_enbl`) only at full extension, and `SM1`'s `extended` flag makes `SM`
fault (`posc_err`) if motion is requested while the extender is out.

Every register, counter and state machine runs on `global_clk` and steps on the
one-cycle `global_clken` pulse from `clocken_generator`.

## Modules

| File                     | Purpose                                 |
| ------------------------ | --------------------------------------- |
| `LogicalStep_Lab4_top.v` | Top module / pin wiring                 |
| `SM.v`                   | X/Y motion state machine                |
| `SM1.v`                  | Extender state machine                  |
| `SM2.v`                  | Grappler state machine                  |
| `REG_4bit.v`             | X/Y target capture registers            |
| `U_D_Bin_Counter4bit.v`  | X/Y position up/down counters           |
| `Compx1.v` / `Compx4.v`  | 1-bit and 4-bit magnitude comparators   |
| `Bidir_shift_reg.v`      | Extender position shift register        |
| `clocken_generator.v`    | Global clock enable generator           |
| `Synch_Inverter2.v`      | Button inverter / filter / synchronizer |
| `SevenSegment.v`         | Hex -> 7-segment decoder                |
| `segment7_mux.v`         | Two-digit display mux + clock divider   |

## Simulation

Uncomment `` `define SIM_FLAG `` at the top of `LogicalStep_Lab4_top.v` to expose
the internal position, target and control signals as virtual pins and run the
clock enable fast. Comment it back out for an FPGA download.
