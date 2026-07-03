# HVAC Controller

An HVAC controller. It ramps a
simulated current temperature toward a target, shows both on the 7-segment
displays, reports status on the LEDs, and has an on-chip self-test for the
magnitude comparator.

## Inputs

- `sw[3:0]` = desired temp (0–F), `sw[7:4]` = vacation temp (0–F).
- Buttons are active-low (`pb_n`), inverted to `pb` by `PB_Inverters`.

| Button                | Does                                                                       |
| --------------------- | -------------------------------------------------------------------------- |
| `pb[0]` door_open     | stops the HVAC while held, lights `leds[5]`                                |
| `pb[1]` window_open   | stops the HVAC while held, lights `leds[4]`                                |
| `pb[2]` MC_test_mode  | freezes the HVAC and displays the comparator self-test status on `leds[7]` |
| `pb[3]` vacation_mode | targets the vacation temp instead of desired, lights `leds[6]`             |

## Outputs

- `DIGIT2` = target temp (mux_temp), `DIGIT1` = current temp.

| LED                 | On when                                             |
| ------------------- | --------------------------------------------------- |
| `leds[0]` furnace   | target > current (heating)                          |
| `leds[1]` at temp   | target = current                                    |
| `leds[2]` AC        | target < current (cooling)                          |
| `leds[3]` blower    | target != current (off during test / door / window) |
| `leds[4]` window    | window_open held                                    |
| `leds[5]` door      | door_open held                                      |
| `leds[6]` vacation  | vacation_mode held                                  |
| `leds[7]` test pass | comparator self-test passing (only in test mode)    |

## Modules

Flow: `PB_Inverters` -> `mux_2to1_4bit` picks the target -> `comp4x` compares it
to the `hvac` current temp -> `Energy_Monitor_Control` drives the HVAC + LEDs.
`Tester` self-checks the comparator; two `SevenSegment` + `segment7_mux` drive the displays.

| File                       | Purpose                                     |
| -------------------------- | ------------------------------------------- |
| `LogicalStep_Lab3_top.v`   | Top module / pin wiring                     |
| `mux_2to1_4bit.v`          | Target temp select (desired vs vacation)    |
| `Compx1.v` / `Compx4.v`    | 1-bit and 4-bit magnitude comparators       |
| `Energy_Monitor_Control.v` | Central control logic (HVAC + status LEDs)  |
| `hvac.v`                   | Current-temp up/down counter                |
| `Tester.v`                 | Comparator self-test                        |
| `SevenSegment.v`           | Hex -> 7-segment decoder                    |
| `segment7_mux.v`           | Two-digit display mux + clock divider       |
| `PB_Inverters.v`           | Active-low button inverter                  |

## Simulation

Uncomment `` `define HVAC_SIM `` at the top of `LogicalStep_Lab3_top.v` to expose
the internal `hvac_temp[3:0]` as virtual pins and run the counter at 50 MHz.
Comment it back out for an FPGA download.
