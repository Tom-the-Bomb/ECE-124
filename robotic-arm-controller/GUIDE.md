# Robotic Arm Controller — A Complete Guide From Zero

This guide assumes you know how to program a little, but **nothing** about
digital hardware, Verilog, or FPGAs. By the end you should be able to look at
any line in this project and know why it's there. Read it top to bottom the
first time; after that it works as a reference.

---

## Table of contents

1. [The 60-second picture](#1-the-60-second-picture)
2. [Verilog & FPGA crash course](#2-verilog--fpga-crash-course)
3. [The architecture: how signals flow](#3-the-architecture-how-signals-flow)
4. [Infrastructure: clock, enable, buttons](#4-infrastructure-clock-enable-buttons)
5. [Datapath building blocks](#5-datapath-building-blocks)
6. [The brains: three state machines](#6-the-brains-three-state-machines)
7. [The top module: wiring it together](#7-the-top-module-wiring-it-together)
8. [End-to-end walkthroughs](#8-end-to-end-walkthroughs)
9. [Design-choice FAQ](#9-design-choice-faq)
10. [Glossary & cheat-sheet](#10-glossary--cheat-sheet)

---

## 1. The 60-second picture

You have a development board (the "LogicalStep" board) with an FPGA chip on it,
plus switches, push-buttons, LEDs, and a two-digit 7-segment display. This
project turns that board into a **Robotic Arm Controller (RAC)** for an imaginary
arm that can:

- **Move** to an X/Y target position (like a plotter head on a rail).
- **Extend / retract** a telescoping arm (the "extender").
- **Open / close** a gripper on the end of the extender (the "grappler").

The board's controls map like this:

| Control               | Meaning                                 |
| --------------------- | --------------------------------------- |
| `sw[7:4]`             | X target, 0–F (a hex digit)             |
| `sw[3:0]`             | Y target, 0–F                           |
| `pb_n[3]`             | Reset everything                        |
| `pb_n[2]`             | "Motion" button — go to the target      |
| `pb_n[1]`             | "Extender" button — extend or retract   |
| `pb_n[0]`             | "Grappler" button — open or close       |
| 7-seg DIGIT1 / DIGIT2 | current X position / current Y position |
| `leds[5:2]`           | extender position bar (`0000`→`1111`)   |
| `leds[1]`             | grappler: 1 = closed, 0 = open          |
| `leds[0]`             | fault light                             |

And there are **safety interlocks** so the three actions can't fight:

- You can only extend when the arm is **stopped**.
- You can only work the grappler when the arm is **fully extended**.
- If you ask the arm to move while the extender is sticking out, it **refuses
  and lights the fault LED** until you retract.

That's the whole product. The rest of the guide is _how_ the hardware pulls it
off.

---

## 2. Verilog & FPGA crash course

Everything below is used somewhere in this project. If a concept feels abstract
now, it'll click when you see it in a real file.

### 2.1 What an FPGA actually is

A normal chip (like a CPU) has fixed circuitry. An **FPGA** (Field-Programmable
Gate Array) is a chip full of _blank_ logic — millions of tiny configurable gates
and thousands of tiny 1-bit memory cells called **flip-flops** — plus a grid of
wires you can connect however you like. You describe the circuit you want in a
language called **Verilog**, a tool (Intel Quartus) compiles it into a
configuration, and the FPGA becomes that circuit.

The crucial mindset shift from software:

> **Verilog is not a list of instructions that run one after another. It
> describes hardware that all exists and runs at the same time.**

Every module, every `assign`, every `always` block is a physical piece of
circuitry that is _always powered and always working in parallel_. There is no
"program counter" stepping through lines. When you write two `assign` statements,
you've built two circuits that both operate continuously and simultaneously.

### 2.2 Bits, buses, and literals

Hardware deals in bits (0 or 1). A **bus** is a bundle of wires carrying several
bits at once. In Verilog:

- `wire x;` — a single 1-bit wire.
- `wire [3:0] x;` — a 4-bit bus. `x[3]` is the **most-significant bit (MSB)**,
  `x[0]` the least. The `[3:0]` reads "bit 3 down to bit 0".
- `4'b1010` — a **literal**: `4` bits, `b`inary, value 1010 (= decimal 10).
- `4'd5` — 4 bits, `d`ecimal, value 5 (= `4'b0101`).
- `1'b1` — one bit, value 1. `1'b0` — one bit, value 0.
- `1'bz` — one bit in the **high-impedance** state (not driven at all — more on
  this later).

So `sw[7:4]` grabs the top four switches as a 4-bit number, and `sw[3:0]` grabs
the bottom four.

### 2.3 `wire` vs `reg` — the single most confusing thing for beginners

- A **`wire`** is just a connection. It doesn't store anything; it always shows
  whatever is currently driving it. You give a wire its value with a continuous
  `assign` (or by connecting it to a module's output).
- A **`reg`** is a variable you assign _inside_ an `always` block. **`reg` does
  NOT automatically mean a hardware register/flip-flop.** It's just "a thing I
  assign procedurally". Whether it becomes actual memory depends on _how_ you
  assign it (see the next two sections).

Rule of thumb: if a signal is driven by `assign` or is a submodule output, it's a
`wire`. If you compute it inside an `always` block, it's a `reg`.

### 2.4 Combinational logic: `assign` and `always @(*)`

**Combinational** logic has no memory. Outputs are a pure function of the current
inputs, recomputed instantly and continuously — like a spreadsheet formula.

Two ways to write it:

```verilog
assign y = a & b;          // continuous assignment: y is always a AND b

always @(*) begin          // "@(*)" = "re-run whenever any input changes"
    y = a & b;             // same circuit, procedural style (y must be a reg)
end
```

The `@(*)` is the **sensitivity list**: the `*` means "watch every signal I read
in here". Any time an input changes, the block instantly recomputes. This is
still combinational — no clock, no memory.

**The latch trap:** in a combinational `always` block you must assign every
output on _every_ possible path. If some path leaves an output unassigned, the
synthesizer thinks "you must want it to _remember_ its old value" and builds an
unwanted memory element (a latch), which causes bugs. The fix, used everywhere in
this project, is **defaults + a `default:` case** so nothing is ever left
unassigned. Keep this in the back of your mind; you'll see it pay off in the
state machines.

### 2.5 Sequential logic: `always @(posedge clk)` and flip-flops

**Sequential** logic has memory. It only changes on the tick of a clock.

```verilog
always @(posedge clk) begin   // run ONLY on the rising edge of clk
    q <= d;                   // remember d; q updates at the edge
end
```

`posedge clk` means "the instant clk goes 0→1". On every rising edge, this block
captures `d` into `q`, and `q` holds that value until the next edge. That's a
**flip-flop** (a.k.a. a register): a 1-bit (or N-bit) memory that samples its
input once per clock tick.

A clock is just a square wave — up, down, up, down — running at a fixed
frequency. This board's master clock, `clkin_50`, runs at **50 MHz**: 50 million
ticks per second, one tick every 20 nanoseconds.

### 2.6 Blocking `=` vs non-blocking `<=`

Two assignment operators, and the difference matters:

- **`<=` (non-blocking):** all the right-hand sides are evaluated first, _then_
  all the left-hand sides update together at the end of the tick. This models
  real flip-flops, which all sample at the same instant. **Use `<=` in clocked
  (`posedge`) blocks.**
- **`=` (blocking):** executes immediately, top to bottom, like normal code.
  **Use `=` in combinational (`@(*)`) blocks.**

Why non-blocking matters: imagine a chain `b <= a; c <= b;` on a clock edge. With
`<=`, both right sides are read _before_ either updates, so `c` gets the _old_
`b` — exactly like two flip-flops in series. With `=`, `c` would grab the
_new_ `b` and you'd have described one flip-flop, not two. Getting this wrong
silently changes your hardware.

(One file in this project, `clocken_generator.v`, mixes the two inside a clocked
block — we'll flag it honestly when we get there.)

### 2.7 Modules and instantiation

A **module** is a reusable block with named ports — think of it as a chip with
labeled pins. You define it once, then **instantiate** (drop in a copy) as many
times as you like:

```verilog
Compx4 U10 (              // "U10" is this copy's instance name
    .a_hex (x_pos),       // connect port a_hex to wire x_pos
    .b_hex (x_capt_reg),
    .a_eq_b (x_eq)
);
```

The `.port (wire)` syntax connects the module's port to a wire in the parent.
Because each instance is real hardware, two instances of `Compx4` are two
separate physical comparators running in parallel. This project has two of almost
everything — one for X, one for Y.

### 2.8 One clock to rule them all — and clock _enables_

A golden rule of FPGA design (drilled into you by the lab manual) is **synchronous
design**: use _one_ clock for the whole chip. Mixing clocks of different speeds
creates timing hazards (metastability, next section). So everything here is
clocked by the single 50 MHz `global_clk`.

But we have a problem: 50 MHz is _way_ too fast for a human to watch the arm
move. If the position counter incremented every clock, it'd fly from 0 to F in
300 nanoseconds. We want it to step maybe twice a second.

The wrong fix is a slower clock (breaks the one-clock rule). The right fix is a
**clock enable**: keep clocking every flip-flop at 50 MHz, but feed in a signal
called `global_clken` that is high for only _one_ clock cycle every so often. The
flip-flops are wired as "on a clock edge, _if_ `global_clken` is high, do the
thing; otherwise hold." So the real clock still runs full speed, but the _action_
happens only on the occasional enable "tick".

You'll see this pattern constantly:

```verilog
always @(posedge clk)
    if (global_clken)        // gate the action, not the clock
        count <= count + 1;
```

Mental model: `global_clk` is the heartbeat (always beating); `global_clken` is a
slow metronome click that says "_now_ is a moment where things are allowed to
advance." The module `clocken_generator.v` produces that metronome click.

### 2.9 Metastability and the input synchronizer

This is the subtlest idea in the project, so we'll take it slowly.

**The rule flip-flops live by.** A flip-flop samples its input `D` at the rising
clock edge, but only behaves if `D` is _stable_ for a tiny window around that edge
(a "setup" time before, a "hold" time after). Stable input → `Q` snaps cleanly to
0 or 1.

**Why a button breaks the rule.** A push-button is **asynchronous** — a human
presses it with no regard for the 50 MHz clock. So eventually it _will_ change
right inside that forbidden window. When you sample a signal mid-change, the
flip-flop can't decide, and `Q` goes **metastable**: it hovers at an in-between
voltage, or wobbles, for an unpredictable time before finally falling to a valid 0
or 1.

**Analogy.** A flip-flop is a ball that wants to rest in one of two valleys, "0"
or "1". A clean input shoves it firmly into a valley. An input caught mid-change
can leave it balanced on the **ridge** between them. It won't stay there — any
tiny noise tips it down — but _which_ side and _how long_ it teeters is random.
The saving grace: the chance it's _still_ teetering decays **exponentially with
time**. Balanced after 1 ns, maybe; still balanced 20 ns later, astronomically
unlikely. **Time is the cure.**

**Why one flip-flop isn't enough.** If your logic reads that one flop's output in
the _same_ cycle, you might read the ball while it's still on the ridge — an
invalid voltage. Worse, two downstream gates can read that same in-between voltage
_differently_ (one sees "0", one sees "1"), so your state machine and your counter
disagree about the button. The design corrupts.

**The two-stage cure.** Sample the scary signal, then _don't look at it for a
whole clock period_ — give the ball time to fall — then re-sample with a second
flop:

```
button ─▶ [FF1] ─▶ [FF2] ─▶ clean, synchronized signal
 (async)   ▲        ▲
          clk      clk
```

- **FF1** samples the button; it's the one that might go metastable.
- **FF2** samples FF1 _one clock edge later_ — after FF1 has had a full period to
  settle. So FF2's output is effectively always clean (real designs go billions of
  years between escapes). FF2's output is the only thing the rest of the chip
  touches.

**What it does _not_ promise:** if the button changed right at the edge, FF1 may
resolve to the old or the new value, so the press might register one clock (~20 ns)
late. That's fine for a button. The guarantee is only "downstream never sees
garbage" — and that's all you need.

**Concrete trace — a press landing exactly on edge C2** (FF1 = `stages_pb[0]`,
FF2 = `stages_pb[1]`):

| edge   | button           | FF1 after                         | FF2 after                     | note                                           |
| ------ | ---------------- | --------------------------------- | ----------------------------- | ---------------------------------------------- |
| C0     | 0                | 0                                 | 0                             | idle                                           |
| C1     | 0                | 0                                 | 0                             | idle                                           |
| **C2** | ↑ _changing now_ | **metastable**, settles before C3 | **0**                         | FF2 sampled FF1's _old_ value (0) → FF2 clean! |
| C3     | 1                | 1                                 | = FF1's settled value (clean) | metastability already gone                     |
| C4     | 1                | 1                                 | 1                             | steady                                         |

The whole insight is the **C2 row**: when FF1 grabs the dangerous changing button,
FF2 simultaneously grabs FF1's _previous, already-settled_ value — never the wobbly
new one. There's always a one-edge gap between "FF1 touches the scary signal" and
"FF2 touches FF1," and that gap is FF1's settling budget.

`Synch_Inverter2.v` builds exactly this chain for each button, and adds a glitch
filter on top — the details (including the release edge) are in §4.2.

### 2.10 Finite state machines (FSMs) — the core idea

Three of the modules are **state machines**, and they're the heart of the design.
An FSM is a system that is always in exactly one of a small set of named
**states**, and it hops between states based on inputs. A traffic light is an
FSM: Green → Yellow → Red → Green.

In this project every FSM is built from **three blocks** (this is a standard,
textbook structure — once you learn it once you can read all three):

1. **Register section** _(sequential — the only clocked block)_
   Holds `current_state`. On each clock edge: if reset, jump to the start state;
   else if `sm_clken` (the enable tick), adopt `next_state`. This is the FSM's
   one piece of memory.

2. **Transition section** _(combinational)_
   A `case` on `current_state` that computes `next_state` from the current state
   and the inputs. "If I'm in state A and button is pressed, next I'll be in B."
   Its _only_ output is `next_state`.

3. **Decoder section** _(combinational)_
   A `case` on `current_state` that sets the machine's **outputs**. "While I'm in
   state B, drive this signal high."

Two flavors of FSM:

- **Moore:** outputs depend only on the _current state_. Outputs change only
  after a clock edge moves you to a new state. Clean and glitch-free.
- **Mealy:** outputs depend on the current state _and_ the inputs directly, so an
  output can react instantly to an input mid-state. Fewer states sometimes, but
  outputs can be glitchy.

All three machines here are written in the Moore style (decode from state), which
is why the files say "Moore state machine". You'll see one small, deliberate
Mealy-ish exception in the motion machine, and we'll call it out.

### 2.11 Why each button gets a "press" AND a "release" state

Here's a subtlety that trips people up. A human holds a button for maybe a
second. At 50 MHz — and even at the slow enable rate — the machine sees the
button "pressed" for _many_ ticks in a row. If a state said "button pressed →
toggle the grappler", it would toggle dozens of times during one physical press.

The fix baked into all three machines: split each action into **two states**.
"Button pressed" moves you into a `PRESS_…` state and stops. You then sit there
until the button is **released** (`~button`), which finally commits the action
and moves you on. This way one physical press-hold-release produces exactly _one_
action. It's edge detection done with states, and it's why the lab manual insists
you "sense the function activation… then wait to sense the function
deactivation." Keep this in mind — it explains half the states you'll see.

---

## 3. The architecture: how signals flow

Here's the whole system as a block diagram. Solid arrows are the main data path;
the interlock signals are called out separately below.

```
   clkin_50 ─▶[GLOBAL buf]─▶ global_clk ──────────────────┐ (clocks EVERYTHING)
                                                           │
   clkin_50 ─▶ clocken_generator ─▶ clken ─▶[GLOBAL buf]─▶ global_clken (the "tick")
                                                           │
   pb_n[3:0] ─▶ Synch_Inverter2 ─▶ reset, motion, extender, grappler (clean, active-high)


   ┌──────────────── X / Y MOTION SUBSYSTEM ────────────────┐
   │                                                        │
   │  sw[7:4]=X_target ─▶ REG_4bit(U6) ─▶ x_capt_reg ─┐     │
   │  sw[3:0]=Y_target ─▶ REG_4bit(U7) ─▶ y_capt_reg ─┼─▶ Compx4(U10/U11)         │
   │                          ▲ load=capture_enable   │      │  ▲                 │
   │                          │                        │      │  │ x_pos,y_pos     │
   │        SM(U3) ───────────┘                        │   x_eq/x_lt/x_gt          │
   │      (motion FSM)  x_cnt_en, x_cnt_up1_dwn0 ─▶ U_D_Bin_Counter4bit(U8) ─▶ x_pos│
   │                    y_cnt_en, y_cnt_up1_dwn0 ─▶ U_D_Bin_Counter4bit(U9) ─▶ y_pos│
   │                                                        x_pos ─▶ SevenSegment ─▶ segment7_mux ─▶ 7-seg
   └────────────────────────────────────────────────────────┘

   ┌──────────────── EXTENDER SUBSYSTEM ────────────────┐
   │  SM1(U4)  extender_dir, extender_in_motion ─▶ Bidir_shift_reg(U15) ─▶ extender_pos ─▶ leds[5:2]
   │ (extender FSM)                       ▲                                     │
   │                                      └───────── extender_pos ──────────────┘
   └────────────────────────────────────────────────────┘

   ┌──────────────── GRAPPLER SUBSYSTEM ────────────────┐
   │  SM2(U5) ─▶ grappler_on ─▶ leds[1]                  │
   └────────────────────────────────────────────────────┘
```

**The three interlock wires that tie the FSMs together** — this is the safety
logic, and it's worth memorizing:

```
   SM  ──extender_enbl──▶ SM1     "extender may run only while the arm is at rest"
   SM1 ──grappler_enbl──▶ SM2     "grappler may run only while fully extended"
   SM1 ──extended──────────▶ SM      "arm is sticking out"  → SM faults if you ask to move
```

So there's a clean hierarchy: the motion machine is the boss (it says when the
extender may act), the extender machine gates the grappler, and the extender
tells the motion machine when it's unsafe to move. Everything else is plumbing.

Now let's read every file. We'll go bottom-up: infrastructure, then the dumb
building blocks, then the smart state machines, then the top that connects them.

---

## 4. Infrastructure: clock, enable, buttons

### 4.1 `clocken_generator.v` — the metronome

This module's whole job: from the always-running 50 MHz clock, produce
`global_clken_source` — a signal that is high for exactly **one clock cycle**
every so often. That's the "tick" from §2.8.

```verilog
module clocken_generator #(parameter sim_flag) (
    input  reset,
    input  global_clk,           // the 50 MHz clock
    output limit_reached,        // an internal strobe you can mostly ignore
    output global_clken_source   // THE tick
);
```

`#(parameter sim_flag)` is a **compile-time knob**. A parameter is a constant
baked in when the module is instantiated. Here `sim_flag` picks between "running
in the simulator" (make ticks fast so you don't wait forever) and "running on the
real board" (make ticks slow enough to watch).

```verilog
    parameter FPGA_DOWNLOAD_CLKEN_COUNT = 32'd10000000,  // board: count to 10 million
              SIMULATION_CLKEN_COUNT    = 32'd16;         // sim: count to 16
```

These are the two "how many clocks between strobes" targets. Ten million clocks
at 20 ns each ≈ **0.2 seconds** on the board. Sixteen clocks ≈ **320 ns** in sim.
Same logic, wildly different speed, chosen by `sim_flag`.

```verilog
    reg clken_limit_reached;
    reg strobe, clk_enbl;

    always @(posedge global_clk) begin
        reg unsigned [24:0] counter;              // a private counter for this block
        if (reset == 1'b1) begin
            clken_limit_reached = 1'b0;
            counter <= 32'd0;
        end
        else if (reset == 1'b0) begin
            if ((sim_flag == 1'b1) && (counter == SIMULATION_CLKEN_COUNT)) begin
                clken_limit_reached = 1'b1;       // hit the target → pulse high, reset
                counter <= 32'd0;
            end
            else if ((sim_flag == 1'b1) && (counter != SIMULATION_CLKEN_COUNT)) begin
                clken_limit_reached = 1'b0;       // not yet → keep counting
                counter <= counter + 1;
            end
            else if ((sim_flag == 1'b0) && (counter == FPGA_DOWNLOAD_CLKEN_COUNT)) begin
                clken_limit_reached = 1'b1;
                counter <= 32'd0;
            end
            else if ((sim_flag == 1'b0) && (counter != FPGA_DOWNLOAD_CLKEN_COUNT)) begin
                clken_limit_reached = 1'b0;
                counter <= counter + 1;
            end
        end
    end
```

Read past the four-way `if` (it's just "sim vs board" × "reached target vs not"):
the counter counts up every clock; when it hits the target it fires
`clken_limit_reached` high for one cycle and resets to 0. So
`clken_limit_reached` is a **periodic one-cycle strobe**.

> **Honesty note (a real code smell):** inside this _clocked_ block,
> `clken_limit_reached` is assigned with **blocking `=`** while `counter` uses
> **non-blocking `<=`**, and other clocked blocks below read
> `clken_limit_reached`. Per §2.6 you should use `<=` in clocked blocks. This
> works in practice but is exactly the kind of mixed-assignment code you should
> _not_ imitate. It's inherited starter code; leave it, but know it's wrong-ish.

```verilog
    // toggle a square wave every time the strobe fires
    always @(posedge global_clk) begin
        if (reset == 1'b1)
            strobe <= 1'b0;
        else if (clken_limit_reached)
            strobe <= ~strobe;
    end

    // final tick: fire on every OTHER strobe (when strobe is currently 0)
    always @(posedge global_clk) begin
        if (reset == 1'b1)
            clk_enbl <= 1'b0;
        else if (reset != 1'b1)
            clk_enbl <= ~strobe & clken_limit_reached;
    end

    assign global_clken_source = clk_enbl;
    assign limit_reached = clken_limit_reached;
endmodule
```

`strobe` flips 0→1→0→1 once per strobe. `clk_enbl = ~strobe & clken_limit_reached`
is high only on strobes where `strobe` is 0 — i.e. **every other strobe**. Net
effect: `global_clken` (what `clk_enbl` becomes) is a clean single-cycle pulse
that repeats at a steady, slow-ish rate. `limit_reached` is the faster
intermediate strobe; the manual literally says "you can ignore this signal", and
you can.

**Takeaway:** you don't need to trace the exact arithmetic. Just hold the
picture: _this module emits one-cycle "go" pulses — very fast in simulation, and
only a few times per second on the board_ (the 10-million count is ~0.2 s, and
the `strobe` halving makes the final tick ~0.4 s apart). Every
counter/register/FSM advances only on those pulses.

### 4.2 `Synch_Inverter2.v` — clean, sane buttons

The push-buttons are **active-low** (`pb_n`): pressed = 0, released = 1 (a common
electrical convention). They're also asynchronous and electrically noisy. This
module fixes all three problems: **invert** (so pressed = 1, which is easier to
reason about), **synchronize** (§2.9), and **filter** (reject blips).

```verilog
module Synch_Inverter2 (
    input       sync_clk,
    input [3:0] pb_n,
    output      sync_reset, sync_motion, sync_extender, sync_grappler
);
    reg [1:0] stages_pb0, stages_pb1, stages_pb2, stages_pb3;
```

Each button gets a **2-bit shift register** (`stages_pbN`) — that's the two-flop
synchronizer, one pair per button.

```verilog
    always @(posedge sync_clk) begin
        stages_pb3[1:0] <= {stages_pb3[0], ~(pb_n[3])};
        stages_pb2[1:0] <= {stages_pb2[0], ~(pb_n[2])};
        stages_pb1[1:0] <= {stages_pb1[0], ~(pb_n[1])};
        stages_pb0[1:0] <= {stages_pb0[0], ~(pb_n[0])};
    end
```

`{stages_pb3[0], ~(pb_n[3])}` is **concatenation** `{high, low}`. Read the
assignment as: "new bit 0 = the inverted button; new bit 1 = the _old_ bit 0." So
each clock the inverted button shifts one stage deeper. Bit 0 is the first
(possibly-metastable) sample; bit 1 is the settled sample. Classic 2-stage
synchronizer, and the `~` does the active-low→active-high inversion in the same
step.

```verilog
    assign sync_reset    = stages_pb3[1] & stages_pb3[0];
    assign sync_motion   = stages_pb2[1] & stages_pb2[0];
    assign sync_extender = stages_pb1[1] & stages_pb1[0];
    assign sync_grappler = stages_pb0[1] & stages_pb0[0];
```

The output is the **AND of both stages**, so it's high only when the button has
read "pressed" for two samples in a row. That's the **glitch filter**: a one-cycle
blip touches only stage 0, so the AND stays low and the blip is ignored. The
commented-out lines below (`= stages_pb3[1];`) are the plain synchronizer _without_
the filter — left as a "here's the simpler version" note.

**"But doesn't ANDing in stage 0 re-expose the metastable flop?"** Good instinct —
let's check both edges. The truly-clean signal is stage 1 alone (it's always
shielded by a full settling period, §2.9); the AND folds stage 0 back in. Watch
what pins the result clean at each _sampling_ edge:

- **Press (button 0→1 at an edge):** during the settling window stage 1 is still
  **0** (it holds stage 0's old value), and `0 AND anything = 0`. Output stays a
  clean 0 until the press genuinely lands.
- **Release (button 1→0 at an edge):** one edge later stage 0 is **0** (button now
  clearly released), and `anything AND 0 = 0`. Output goes cleanly to 0.

So at every clock edge **at least one stage is a settled, clean value** — a settled
`0` pins the AND, a settled `1` defers to the other (also settled) stage. The two
stages are never _both_ wobbling at an edge. Any transient wobble lives strictly
_between_ edges, and the only readers are the FSM registers, which sample **only at
edges** — by which point stage 0 has settled. So the AND is safe _and_ free:
stage 1 kills metastability, the AND kills noise. Worst case, a transition just
registers one clock (~20 ns) later.

Result: four clean, synchronous, active-high signals — `reset`, `motion`,
`extender`, `grappler` — safe to feed to the rest of the chip.

### 4.3 The `GLOBAL` buffers (defined in the top file)

You'll see these two lines in the top module:

```verilog
GLOBAL GLOBAL_CLOCK (.in(clkin_50), .out(global_clk));
GLOBAL GLOBAL_CLKEN (.in(clken),    .out(global_clken));
```

`GLOBAL` is a built-in Intel/Altera primitive (not a file in this project). An
FPGA has special low-skew "global" wires designed to deliver a clock/enable to
thousands of flip-flops at _nearly the same instant_. Putting the clock and the
enable onto those dedicated networks keeps the whole chip in lockstep. Think of it
as "promote this signal to the VIP express lane." Functionally `out = in`; the
magic is _which physical wires_ it uses.

---

## 5. Datapath building blocks

These modules are "dumb" — no decisions, just storing, counting, comparing,
displaying. The state machines drive them.

### 5.1 `REG_4bit.v` — a 4-bit memory with load enable

Used twice, to freeze the X and Y targets the moment you press Motion.

```verilog
module REG_4bit (
    input  wire       clk,
    input  wire       load,
    input  wire [3:0] data,
    input  wire       reset,
    output reg  [3:0] target_reg
);
    always @(posedge clk) begin
        if (reset)
            target_reg <= 4'b0000;   // reset wins
        else if (load)
            target_reg <= data;      // capture data when told to
        // else: hold (no assignment → keep the stored value)
    end
endmodule
```

This is a textbook register with **synchronous reset** and **load enable**. On
each clock edge: reset beats everything; otherwise, _if_ `load` is high, snapshot
`data`; otherwise hold. When Motion is pressed, the motion FSM raises `load`
(named `capture_enable`), so `target_reg` grabs the switch value and then keeps it
even if you fiddle the switches afterward. That's how the target is "locked in."

(The comment "increment or decrement… counter" is leftover copy-paste from the
counter file — ignore it; this module doesn't count.)

### 5.2 `U_D_Bin_Counter4bit.v` — the position counter (up/down, saturating)

Two of these track the arm's actual X and Y position.

```verilog
module U_D_Bin_Counter4bit (
    input  wire       clk,
    input  wire       global_clken,   // only step on the tick
    input  wire       count_en,       // only step when enabled
    input  wire       count_up1_dwn0, // 1 = up, 0 = down
    input  wire       reset,
    output reg  [3:0] count
);
    always @(posedge clk) begin
        if (reset)
            count <= 4'b0000;
        else if ((global_clken & count_en & count_up1_dwn0) & (count != 4'b1111))
            count <= count + 4'd0001;   // count up, but stop at F
        else if ((global_clken & count_en & (!count_up1_dwn0)) & (count != 4'b0000))
            count <= count - 4'd0001;   // count down, but stop at 0
    end
endmodule
```

Read the "up" condition as four things that must _all_ be true:
`global_clken` (it's a tick moment) **and** `count_en` (the FSM allows counting)
**and** `count_up1_dwn0` (direction is up) **and** `count != 1111` (not already
maxed). Only then does it add one. The `count != 1111` / `count != 0000` guards
make it **saturate** — it clamps at the ends instead of wrapping F→0. The literal
`4'd0001` is just a fancy way of writing `1`.

Because `global_clken` is in the condition, the counter advances **one step per
tick** — that's what makes the position crawl at a watchable pace.

### 5.3 `Bidir_shift_reg.v` — the extender position

The extender's physical extension is represented as a **thermometer code** in a
4-bit shift register: `0000` (in) → `1000` → `1100` → `1110` → `1111` (fully out).
Each 1 is one segment of extension, and they light up `leds[5:2]`.

```verilog
module Bidir_shift_reg (
    input        clock,
    input        reset,
    input        extender_clken,   // = global_clken (the tick)
    input        extender_enbl,    // = "in motion" from SM1
    input        extender_dir,     // 1 = extend, 0 = retract
    output [3:0] reg_bits
);
    reg [3:0] sreg;

    always @(posedge clock) begin
        if (reset == 1'b1)
            sreg <= 4'b0000;
        else if ((extender_clken) && (extender_enbl == 1'b1))
            if (extender_dir == 1'b1)           // extend
                sreg <= {1'b1, sreg[3:1]};      // shove a 1 in at the top
            else if (extender_dir == 1'b0)      // retract
                sreg <= {sreg[2:0], 1'b0};      // shove a 0 in at the bottom
    end

    assign reg_bits = sreg;
endmodule
```

The two concatenations are the whole trick:

- **Extend** `{1'b1, sreg[3:1]}`: new MSB = 1, and the old bits slide down one
  position (old bit 3 → new bit 2, etc.), dropping old bit 0. Starting from
  `0000`: → `1000` → `1100` → `1110` → `1111`. Ones pile in from the top.
- **Retract** `{sreg[2:0], 1'b0}`: everything slides up one, a 0 enters at the
  bottom, and the top bit falls off. From `1111`: → `1110` → `1100` → `1000` →
  `0000`.

Like the counter, it only moves on a tick (`extender_clken`) and only while SM1
says it's `in motion`. One position per tick, so you watch the bar grow and
shrink on the LEDs.

### 5.4 `Compx1.v` — a 1-bit comparator

The atom of comparison: given two bits, is `a` equal to, greater than, or less
than `b`?

```verilog
module Compx1 (
    input      a,
    input      b,
    output reg aeqb,
    output reg agtb,
    output reg altb
);
    always @(*) begin
        aeqb = (a & b) | ((!(a)) & (!(b)));  // equal: both 1 or both 0 (that's XNOR)
        agtb = a & (!(b));                   // a>b only when a=1, b=0
        altb = (!(a)) & b;                   // a<b only when a=0, b=1
    end
endmodule
```

For single bits, "greater" can only mean 1-vs-0. This is pure combinational logic
(`@(*)`), so the three outputs update the instant `a` or `b` changes.

### 5.5 `Compx4.v` — a 4-bit magnitude comparator

Compares two 4-bit numbers by wiring up four `Compx1`s and combining them the way
_you_ compare multi-digit numbers: **start at the most significant bit; the first
bit where they differ decides it.**

```verilog
    Compx1 Bit3_COMP (.a(a_hex[3]), .b(b_hex[3]), .aeqb(aeqb[3]), ...);
    Compx1 Bit2_COMP (.a(a_hex[2]), .b(b_hex[2]), ...);
    Compx1 Bit1_COMP (.a(a_hex[1]), .b(b_hex[1]), ...);
    Compx1 Bit0_COMP (.a(a_hex[0]), .b(b_hex[0]), ...);

    always @(*) begin
        a_eq_b = aeqb[3] & aeqb[2] & aeqb[1] & aeqb[0];   // equal iff every bit equal

        a_gt_b = agtb[3]
               | (aeqb[3] & agtb[2])
               | (aeqb[3] & aeqb[2] & agtb[1])
               | (aeqb[3] & aeqb[2] & aeqb[1] & agtb[0]);
        // a_lt_b: same shape, with "less-than" at each bit
    end
```

Read `a_gt_b` as: "a > b if bit 3 is greater; **or** bit 3 ties and bit 2 is
greater; **or** bits 3,2 tie and bit 1 is greater; **or** bits 3,2,1 tie and bit 0
is greater." That's exactly how you'd compare `1010` vs `1001` by eye. `a_lt_b` is
the mirror image.

In this project `a` = the arm's current position and `b` = the captured target.
So the outputs mean: `x_gt` = past the target, `x_lt` = not there yet, `x_eq` =
arrived. The motion FSM uses `x_lt` to pick direction (behind target → count up)
and `x_eq` to know when to stop.

### 5.6 `SevenSegment.v` — hex digit → segment pattern

A 7-segment display is seven little bars (a–g) arranged in a figure-8. To show a
digit you light the right subset. This module is a **lookup table** from a 4-bit
value to its 7-bit pattern.

```verilog
    //   +---- a -----+
    //   |            |
    //   f            b
    //   |            |
    //   +---- g -----+
    //   |            |
    //   e            c
    //   |            |
    //   +---- d -----+
    //                        hex bits      sevenseg
    //                          3210        GFEDCBA
    assign sevenseg =
        (hex == 4'b0000) ? 7'b0111111 :   // "0": every segment except g
        (hex == 4'b0001) ? 7'b0000110 :   // "1": just b and c
        ...
        (hex == 4'b1111) ? 7'b1110001 :   // "F"
                           7'b0000000;    // anything else: blank
```

The `? :` is a **ternary (2:1 mux)**, and chaining them makes a priority lookup:
"if hex==0 use this pattern, else if hex==1 use that…". The bit order is `GFEDCBA`
(bit 0 = segment a). So for "1" = `0000110`, only bits 1 and 2 (segments b and c —
the two right-hand bars) are on. This is just the font; the actual on/off polarity
and digit steering happen next door in `segment7_mux`.

### 5.7 `segment7_mux.v` — showing two digits on one set of wires

The board has two digits but (to save pins) they _share_ the seven segment wires.
The trick is **time-multiplexing**: show digit 1 for a sliver of time, then digit
2, then digit 1… fast enough that your eye sees both lit at once (persistence of
vision, same as how a screen "flickers" too fast to notice).

```verilog
    reg [31:0] count;
    always @(posedge clk) begin
        count <= count + 1;        // free-running counter, never stops
    end
    assign toggle = count[10];     // bit 10 flips every 1024 clocks (~20 µs)
```

A big counter runs continuously; bit 10 is a square wave that flips every 1024
clocks — about 20 µs, so each digit is shown ~20 µs at a time (≈24 kHz refresh,
invisibly fast).

```verilog
    assign dig1 = ~(toggle);       // digit-enable lines, opposite phases
    assign dig2 = toggle;

    assign dout_mux[0] = (toggle == 1'b1) ? din2[0] : din1[0];   // pick which digit's
    ...                                                          // pattern to show now
    assign dout_mux[6] = (toggle == 1'b1) ? din2[6] : din1[6];
```

When `toggle` is 0, digit 1 is enabled and `dout_mux` shows `din1`'s pattern; when
`toggle` is 1, digit 2 is enabled and it shows `din2`. The two never conflict
because only one digit-enable is active at a time.

```verilog
    // some segment lines must be "open-drain": drive low, or float instead of driving high
    assign dout_temp[0] = (dout_mux[0] == 1'b1) ? 1'b1 : 1'b0;
    assign dout_temp[1] = (dout_mux[1] == 1'b1) ? 1'bz : 1'b0;  // open drain (float when "on")
    ...
```

`1'bz` is **high-impedance** — the pin drives _nothing_ (floats) instead of a
logic 1. Some segment pins on this particular PCB are wired so they must be
pulled up externally, not driven high by the FPGA. So for those, "on" = release
the pin (`z`) and "off" = pull low (`0`). This is a board-electrical detail, not
logic; you can treat it as "quirk required by the physical display."

---

## 6. The brains: three state machines

Now the payoff. Each machine follows the exact three-block skeleton from §2.10.
We'll do the simplest first (grappler), matching the order the lab manual tells
you to build them.

### 6.0 The shared skeleton (read once, applies to all three)

```verilog
parameter STATE_A = ..., STATE_B = ...;      // give each state a name + a number
reg [n:0] current_state, next_state;         // the FSM's memory + its next value

// (1) REGISTER — the only clocked block
always @(posedge clock) begin
    if (reset)          current_state <= START_STATE;   // reset → known start
    else if (sm_clken)  current_state <= next_state;    // advance only on a tick
end

// (2) TRANSITION — combinational; computes next_state from current_state + inputs
always @(*) begin
    case (current_state) ... endcase
end

// (3) DECODER — combinational; sets outputs from current_state
always @(*) begin
    <defaults for every output>       // ← prevents latches (§2.4)
    case (current_state) ... endcase
end
```

Three things to notice every time:

- The **only** `posedge` block is the register — that's the single bundle of
  flip-flops. Transition and decoder are pure combinational.
- The register advances **only when `sm_clken` is high** — that's `global_clken`,
  the tick. So the FSM takes one step per tick, in sync with the counters and
  shift register it controls. This is also why a button must be _held_ long
  enough to overlap a tick — otherwise the machine never samples it.
- The decoder sets **defaults first**, then the `case` overrides. Combined with a
  `default:` branch, every output is assigned on every path → no accidental
  latches.

### 6.1 `SM2.v` — the grappler (4 states)

Goal: each full press-hold-release **toggles** the grappler between open and
closed — but only when SM1 says it's allowed (`grappler_enbl`, i.e. fully
extended).

States and the ring they form:

```
  OPEN ──[enbl & grappler]──▶ PRESS_TO_CLOSE ──[release]──▶ CLOSED ──[enbl & grappler]──▶ PRESS_TO_OPEN ──[release]──▶ (back to OPEN)
 out=0                         out=0                      out=1                          out=1
```

(Each state also _self-loops_ — stays put — until its condition is met.)

```verilog
    parameter OPEN = 2'b00, PRESS_TO_CLOSE = 2'b01, CLOSED = 2'b10, PRESS_TO_OPEN = 2'b11;
```

Two bits encode four states. The names are the whole point — you never think in
`2'b01`, you think "PRESS_TO_CLOSE".

```verilog
    // TRANSITION
    case (current_state)
        OPEN:        next_state = (grappler_enbl && grappler) ? PRESS_TO_CLOSE : OPEN;
        PRESS_TO_CLOSE: next_state = grappler ? PRESS_TO_CLOSE : CLOSED;   // wait for release
        CLOSED:      next_state = (grappler_enbl && grappler) ? PRESS_TO_OPEN : CLOSED;
        PRESS_TO_OPEN:  next_state = grappler ? PRESS_TO_OPEN : OPEN;      // wait for release
        default:     next_state = OPEN;                             // safety net
    endcase
```

Trace it: sitting in `OPEN`, nothing happens until _both_ `grappler_enbl` and
`grappler` are high — then you hop to `PRESS_TO_CLOSE` and **stop**. You stay in
`PRESS_TO_CLOSE` as long as the button is still held (`grappler` high); the moment
it's released, `~grappler`, you fall to `CLOSED`. Now the gripper is closed and
stays closed. The next press-release does the mirror trip back to `OPEN`. This is
the press/release two-state pattern from §2.11, and it's why toggling is exactly
once per press.

```verilog
    // DECODER (Moore: output depends only on state)
    case (current_state)
        CLOSED, PRESS_TO_OPEN: grappler_on = 1'b1;   // "closed" during both these states
        default:            grappler_on = 1'b0;
    endcase
```

`grappler_on` is high in `CLOSED` **and** `PRESS_TO_OPEN`. Why both? Because
`PRESS_TO_OPEN` means "currently closed, you've pressed to reopen, but haven't let go
yet" — physically still closed until the release commits. So the output correctly
stays closed through the press.

### 6.2 `SM1.v` — the extender (6 states)

Goal: press-hold-release toggles between extending and retracting; the actual
motion runs (driving the shift register) until it hits the end stop. Plus it
publishes two status signals to the other machines.

```
 RETRACTED ─[enbl&ext]─▶ PRESS_TO_EXTEND ─[release]─▶ EXTENDING ─[pos==1111]─▶ EXTENDED
     ▲                                              dir=1,                     │
     │                                             in_motion=1                 │ [enbl&ext]
 [pos==0000]                                                                   ▼
     │                                                                    PRESS_TO_RETRACT
  RETRACTING ◀───────────────── [release] ─────────────────────────────────┘
   dir=0, in_motion=1
```

```verilog
    parameter RETRACTED     = 3'b000,
              PRESS_TO_EXTEND   = 3'b001,
              EXTENDING      = 3'b010,
              EXTENDED       = 3'b011,
              PRESS_TO_RETRACT  = 3'b100,
              RETRACTING     = 3'b101;
```

Six states need 3 bits (`reg [2:0]`). Notice the two "moving" states
(`EXTENDING`, `RETRACTING`) that don't exist in the grappler machine — the
extender has to _travel_, and travel takes many ticks.

```verilog
    // TRANSITION
    case (current_state)
        RETRACTED:     next_state = (extender_enbl && extender) ? PRESS_TO_EXTEND : RETRACTED;
        PRESS_TO_EXTEND:  next_state = extender ? PRESS_TO_EXTEND : EXTENDING;   // release → start moving
        EXTENDING:     next_state = (extender_pos == 4'b1111) ? EXTENDED : EXTENDING;   // travel until full
        EXTENDED:      next_state = (extender_enbl && extender) ? PRESS_TO_RETRACT : EXTENDED;
        PRESS_TO_RETRACT: next_state = extender ? PRESS_TO_RETRACT : RETRACTING;
        RETRACTING:    next_state = (extender_pos == 4'b0000) ? RETRACTED : RETRACTING;  // travel until in
        default:       next_state = RETRACTED;
    endcase
```

The press/release pair (`RETRACTED → PRESS_TO_EXTEND → EXTENDING`) is the same idea
as before. The new bit is `EXTENDING`: it just waits, checking the shift
register's reported position (`extender_pos`) until it reads `1111`, then declares
`EXTENDED`. It doesn't count itself — it _watches_ the `Bidir_shift_reg` it's
driving. `RETRACTING` mirrors it, waiting for `0000`.

```verilog
    // DECODER
    extender_in_motion = 1'b0;                       // defaults
    extender_dir       = 1'b0;
    grappler_enbl      = 1'b0;
    extended           = (extender_pos != 4'b0000);  // ← computed from position, not state
    case (current_state)
        EXTENDING:  begin extender_in_motion = 1'b1; extender_dir = 1'b1; end   // move, outward
        RETRACTING: begin extender_in_motion = 1'b1; extender_dir = 1'b0; end   // move, inward
        EXTENDED, PRESS_TO_RETRACT: grappler_enbl = 1'b1;   // grappler allowed only at full extension
        default: ;   // RETRACTED / PRESS_TO_EXTEND: defaults are already correct
    endcase
```

Three outputs, three ideas:

- **`extender_in_motion` + `extender_dir`** are only active in the two moving
  states, and they're exactly what `Bidir_shift_reg` needs ("shift now" +
  "which way"). So SM1 _is_ the thing pushing the extender in and out, one tick at
  a time.
- **`grappler_enbl`** is the interlock to SM2: high only at full extension
  (`EXTENDED`, and `PRESS_TO_RETRACT` which is still fully extended until you let
  go). This is _why_ the grappler refuses to move unless the arm is all the way
  out.
- **`extended`** is set _outside_ the `case`, straight from the position:
  `extender_pos != 0000`. It's high the instant the extender leaves home and
  stays high until it's fully back. This feeds the motion machine's fault check.
  (Deriving it from position rather than state means it's true even mid-travel.)

### 6.3 `SM.v` — the X/Y motion controller (4 states)

The most involved machine: capture the target, drive two counters toward it,
enforce the fault interlock.

```
   AT_REST ─[motion & extended]─▶ FAULT ─[~extended & ~motion]─▶ AT_REST   (FAULT: posc_err=1, locked)
     │
     │ [motion & extender home]
     ▼
   CAPTURE ─[release]─▶ MOVING ─[x_eq & y_eq]─▶ AT_REST
   (CAPTURE: capture_enable=1;   MOVING: counters run toward target)
```

```verilog
    parameter AT_REST = 2'b00, CAPTURE = 2'b01, MOVING = 2'b10, FAULT = 2'b11;
```

```verilog
    // TRANSITION
    case (current_state)
        AT_REST:    if (motion && extended)  next_state = FAULT;    // illegal: move while stuck out
                 else if (motion)         next_state = CAPTURE;  // legal: begin
                 else                     next_state = AT_REST;
        CAPTURE: next_state = motion ? CAPTURE : MOVING;           // wait for release, then move
        MOVING:    next_state = (x_eq && y_eq) ? AT_REST : MOVING;      // done when BOTH axes arrive
        FAULT:   next_state = (!extended && !motion) ? AT_REST : FAULT;  // locked until retracted + released
        default: next_state = AT_REST;
    endcase
```

Walk the happy path: in `AT_REST`, press Motion while the extender is home
(`~extended`) → go to `CAPTURE`. Hold it → stay in `CAPTURE` (this is where the
target gets latched, see decoder). Release → go to `MOVING`. In `MOVING` the counters
crawl toward the target every tick; the machine sits here until _both_ `x_eq` and
`y_eq` are true, then returns to `AT_REST`, ready for the next target.

The `FAULT` branch is the interlock: if you press Motion while `extended` is high,
you don't move — you jump to `FAULT` and light the error LED. You're stuck there
until the extender is fully retracted (`~extended`) **and** you've released the
button (`~motion`). "Retract to clear the fault," exactly as specified.

```verilog
    // DECODER
    capture_enable = 0; x_cnt_en = 0; x_cnt_up1_dwn0 = 0;    // defaults: everything off
    y_cnt_en = 0; y_cnt_up1_dwn0 = 0; extender_enbl = 0; posc_err = 0;
    case (current_state)
        AT_REST:    extender_enbl = 1'b1;                        // at rest → extender may run
        CAPTURE: begin capture_enable = 1'b1; extender_enbl = 1'b1; end   // latch target
        MOVING: begin
            x_cnt_en       = !x_eq;    // keep X counting until it matches
            x_cnt_up1_dwn0 = x_lt;     // behind target → up; past it → down
            y_cnt_en       = !y_eq;
            y_cnt_up1_dwn0 = y_lt;
        end
        FAULT: begin posc_err = 1'b1; extender_enbl = 1'b1; end   // error on; allow retract to clear
        default: ;
    endcase
```

The outputs, one idea at a time:

- **`capture_enable`** is high only in `CAPTURE`. It's the `load` on the two
  `REG_4bit`s — that's the moment the switch values become the locked-in target.
  Because you're _holding_ Motion during `CAPTURE`, it loads on every tick you
  hold, which is harmless (same value each time). Once you release into `MOVING`,
  it goes low, so changing the switches mid-move can't hijack the target.
- **`x_cnt_en = !x_eq`** — count X only while it hasn't arrived. The moment
  `x_eq` goes true, the enable drops and X freezes. This is what lets one axis
  stop while the other keeps going: they each stop on their own `_eq`.
- **`x_cnt_up1_dwn0 = x_lt`** — direction from the comparator: if position < target
  (`x_lt`), count up; otherwise down. No manual direction logic needed; the
  comparator already knows which way to go.
- **`extender_enbl`** is high in every state _except_ `MOVING` (`AT_REST`, `CAPTURE`,
  `FAULT`). Meaning: "the arm is not currently traversing, so the extender is
  allowed to operate." That's the interlock feeding SM1. During `FAULT` it's
  deliberately on, because clearing the fault _requires_ retracting the extender.
- **`posc_err`** — the fault lamp, on only in `FAULT`.

> **The one Mealy wrinkle:** in `MOVING`, outputs like `x_cnt_en` depend on `x_eq`
> and `x_lt`, which are _inputs_ (comparator results), not just the state. So this
> decoder is technically Mealy-flavored, even though the file calls itself Moore.
> That's fine and common — it's what lets the counters react to "arrived" within
> the same state instead of needing a separate stop-state per axis. Just know that
> "pure Moore" is an ideal the motion machine bends slightly, on purpose.

### 6.4 The interlock web, in one place

Putting the three decoders together, here's the safety logic that emerges:

- **To move**, the extender must be home. If not, `extended` is high, and pressing
  Motion sends SM to `FAULT` instead of `CAPTURE`. → _No moving with the arm out._
- **To extend**, `extender_enbl` from SM must be high, which only happens when SM
  is **not** in `MOVING`. → _No extending while traversing._
- **To grapple**, `grappler_enbl` from SM1 must be high, which only happens at
  **full extension**. → _No gripping unless fully out._

Three little wires, and the whole "only one function at a time, safely" behavior
falls out. No global referee needed — each machine just gates the next.

---

## 7. The top module: wiring it together

`LogicalStep_Lab4_top.v` has almost no logic of its own. It declares the pins,
instantiates all the blocks, and connects them. This is the "schematic in text"
that realizes the block diagram from §3.

### 7.1 The `SIM_FLAG` trick and the port list

```verilog
//`define SIM_FLAG          // commented out = build for the real board

module LogicalStep_Lab4_top (
    input        clkin_50,
    input  [3:0] pb_n,
    input  [7:0] sw,
    output [7:0] leds,
`ifdef SIM_FLAG
    output [3:0] xreg, yreg,     // extra "virtual pins" that only exist in simulation
    output [3:0] xPOS, yPOS,
    ...
`endif
    output [6:0] seg7_data,
    output       seg7_char1,
    output       seg7_char2
);
```

`` `define SIM_FLAG `` / `` `ifdef `` are **compiler directives** — they run at
compile time, before any hardware exists, like `#ifdef` in C. When `SIM_FLAG` is
defined, a pile of extra outputs (internal signals like the captured target and
live position) get exposed as ports so you can watch them in the simulator. When
it's commented out (as shipped), those ports vanish and you get a lean design that
fits the real board's actual pins. **One source file, two builds.**

### 7.2 The infrastructure instances

```verilog
    clocken_generator #(.sim_flag (sim_flag)) U1 ( ... );   // the tick generator
    Synch_Inverter2 U2 ( .pb_n(pb_n), .sync_reset(reset), .sync_motion(motion), ... );
    GLOBAL GLOBAL_CLOCK (.in(clkin_50), .out(global_clk));  // clock onto the global net
    GLOBAL GLOBAL_CLKEN (.in(clken),    .out(global_clken));// enable onto the global net
```

`sim_flag` is a `localparam` set to 1 or 0 by the same `` `ifdef SIM_FLAG ``, and
it's passed into `clocken_generator` to pick fast-vs-slow ticks. `U2` turns the
four raw buttons into the clean `reset`/`motion`/`extender`/`grappler` signals
every other block uses.

### 7.3 The X/Y motion subsystem

```verilog
    SM U3 ( .clock(global_clk), .reset(reset), .sm_clken(global_clken),
            .motion(motion), .extended(extended),
            .x_eq(x_eq), .x_lt(x_lt), .x_gt(x_gt),
            .y_eq(y_eq), .y_lt(y_lt), .y_gt(y_gt),
            .capture_enable(capture_enable),
            .x_cnt_en(x_cnt_en), .x_cnt_up1_dwn0(x_cnt_up1_dwn0),
            .y_cnt_en(y_cnt_en), .y_cnt_up1_dwn0(y_cnt_up1_dwn0),
            .extender_enbl(extender_enbl), .posc_err(posc_err) );

    assign x_target = sw[7:4];
    REG_4bit U6 (.clk(global_clk), .reset(reset), .load(capture_enable),
                 .data(x_target), .target_reg(x_capt_reg));      // latch X target
    assign y_target = sw[3:0];
    REG_4bit U7 ( ... .data(y_target), .target_reg(y_capt_reg)); // latch Y target

    U_D_Bin_Counter4bit U8 ( ... .count_en(x_cnt_en), .count_up1_dwn0(x_cnt_up1_dwn0),
                             .count(x_pos));                       // live X position
    U_D_Bin_Counter4bit U9 ( ... .count(y_pos));                  // live Y position

    Compx4 U10 (.a_hex(x_pos), .b_hex(x_capt_reg), .a_eq_b(x_eq), .a_gt_b(x_gt), .a_lt_b(x_lt));
    Compx4 U11 (.a_hex(y_pos), .b_hex(y_capt_reg), ...);          // compare pos vs target

    SevenSegment U12 (.hex(x_pos), .sevenseg(seg7_x));
    SevenSegment U13 (.hex(y_pos), .sevenseg(seg7_y));
    segment7_mux U14 (.din1(seg7_x), .din2(seg7_y), .dout(seg7_data),
                      .dig1(seg7_char1), .dig2(seg7_char2));

    assign leds[0] = posc_err;
```

Trace the loop it forms — this _is_ the motion feedback control:

```
 SM ──cnt_en/dir──▶ counter ──x_pos──▶ Compx4 ──x_eq/x_lt──▶ back into SM
                       │
                       └──x_pos──▶ SevenSegment ──▶ segment7_mux ──▶ display
```

SM tells the counter to step; the counter's new position goes to the comparator;
the comparator tells SM "not there / arrived / overshot"; SM decides whether to
keep stepping. Around and around, once per tick, until `x_eq && y_eq`. The
position is continuously shown on the 7-seg display.

### 7.4 The extender and grappler subsystems

```verilog
    SM1 U4 ( .clock(global_clk), .reset(reset), .sm_clken(global_clken),
             .extender_enbl(extender_enbl),   // ← from SM (motion machine)
             .extender(extender),
             .extender_pos(extender_pos),     // ← feedback from the shift register
             .extender_in_motion(extender_in_motion),
             .extender_dir(extender_dir),
             .extended(extended),             // → to SM (fault check)
             .grappler_enbl(grappler_enbl) ); // → to SM2

    Bidir_shift_reg U15 ( .clock(global_clk), .reset(reset),
             .extender_clken(global_clken),
             .extender_enbl(extender_in_motion),   // "in motion" gates the shifting
             .extender_dir(extender_dir), .reg_bits(extender_pos) );
    assign leds[5:2] = extender_pos[3:0];

    SM2 U5 ( .clock(global_clk), .reset(reset), .sm_clken(global_clken),
             .grappler_enbl(grappler_enbl),   // ← from SM1
             .grappler(grappler), .grappler_on(grappler_on) );
    assign leds[1] = grappler_on;
```

Notice the same feedback shape: `SM1 → Bidir_shift_reg → extender_pos → back into
SM1`. The machine drives the shift register and watches its position to know when
to stop — a mirror of the motion loop. And the three cross-module interlock wires
from §6.4 are right here in plain sight: `extender_enbl` (SM→SM1), `extended`
(SM1→SM), `grappler_enbl` (SM1→SM2).

### 7.5 Two things that look wrong but aren't

1. **Forward references.** Wires like `reset`, `extended`, `extender_enbl`, and
   `grappler_enbl` are _used_ in instances near the top of the file but _declared_
   (`wire …;`) further down, inside the section they logically belong to. Verilog
   allows this for simple nets, and Quartus resolves it fine. (Some strict linters
   grumble; it's harmless here.)

2. **`x_gt` / `y_gt` look unused.** The motion machine only needs `x_lt` (pick
   direction) and `x_eq` (know when to stop) — `x_gt` is redundant (if not equal
   and not less-than, it must be greater). The `_gt` ports are wired up anyway
   because the comparator produces all three and the block diagram shows them;
   leaving them connected costs nothing and keeps the interface faithful to the
   documented design.

### 7.6 The simulation-only tail

```verilog
`ifdef SIM_FLAG
    assign xreg = x_capt_reg[3:0];
    assign xPOS = x_pos[3:0];
    ...
`endif
```

When building for simulation, these bolt the interesting internal signals onto the
extra ports from §7.1 so you can graph them in the waveform viewer. In the real
build they don't exist. Purely a debugging convenience.

---

## 8. End-to-end walkthroughs

Time to watch the whole machine breathe. Each "tick" below is one `global_clken`
pulse (the register and everything else advance together on it). Assume you've hit
reset first, so all machines are at their start states and positions are 0.

### 8.1 Scenario A — move to (X=5, Y=3)

1. Set `sw[7:4]=5`, `sw[3:0]=3`. Nothing captured yet.
2. **Press & hold Motion.** SM is in `AT_REST`; extender is home so `extended=0`;
   `motion=1` → next state `CAPTURE`. On the next tick SM enters `CAPTURE`.
3. **In `CAPTURE`** (still holding): `capture_enable=1`, so `REG_4bit` U6/U7 latch
   `x_capt_reg=5`, `y_capt_reg=3`. It reloads each tick you hold — same values, no
   harm.
4. **Release Motion.** `motion=0` → `CAPTURE` transitions to `MOVING`.
5. **In `MOVING`**, each tick: `x_pos` starts at 0, comparator says `x_lt=1` (0<5),
   so `x_cnt_en=1, up`. X counts 0→1→2→3→4→5. Meanwhile Y counts 0→1→2→3. The
   display shows both climbing.
6. Y reaches 3 first (`y_eq=1` → `y_cnt_en=0`, Y freezes at 3) while X keeps going
   to 5. This is the "one axis stops, the other continues" requirement, and it
   falls out of `cnt_en = !eq` per axis.
7. When X also hits 5, `x_eq && y_eq` → SM returns to `AT_REST`. Arm is parked at
   (5,3). You can now set a new target and press Motion again.

### 8.2 Scenario B — extend, grab something, retract

1. Arm at rest (SM in `AT_REST`), so `extender_enbl=1` — the extender is allowed.
2. **Press & release Extender.** SM1: `RETRACTED → PRESS_TO_EXTEND` (on press) →
   `EXTENDING` (on release).
3. **`EXTENDING`** drives `extender_in_motion=1, dir=1`. Each tick,
   `Bidir_shift_reg` fills in a 1: `0000→1000→1100→1110→1111`, shown on
   `leds[5:2]`. As soon as it left `0000`, `extended` went high (so motion is now
   locked out — see Scenario C).
4. At `1111`, SM1 → `EXTENDED`. Now `grappler_enbl=1`.
5. **Press & release Grappler.** SM2: `OPEN → PRESS_TO_CLOSE → CLOSED`;
   `grappler_on=1` (leds[1] on). Gripper closed. (This only worked because
   `grappler_enbl` was high.)
6. **Press & release Extender** again. SM1: `EXTENDED → PRESS_TO_RETRACT →
RETRACTING`, `dir=0`, and the bar drains `1111→1110→…→0000`. At `0000`, SM1 →
   `RETRACTED`, `extended` drops, and motion is allowed again.

### 8.3 Scenario C — the fault, and clearing it

1. Suppose the extender is out (`extended=1`) and you **press Motion** anyway.
2. SM is in `AT_REST`; `motion && extended` is true → SM jumps to `FAULT` (not
   `CAPTURE`). No counters run; `posc_err=1` lights `leds[0]`.
3. SM is now **locked**: the transition out of `FAULT` requires `~extended &&
~motion`. Releasing the button isn't enough — the extender is still out.
4. **Retract the extender fully** (Scenario B step 6). Once `extended` drops to 0
   _and_ the Motion button is released, SM finally returns to `AT_REST`, `posc_err`
   clears, and normal motion is available again. "Retract to clear," as specified.

Play these three traces in your head a couple of times and the entire design
collapses into something simple: _three little state machines, each stepping once
per tick, each driving one dumb datapath block and gating the next machine._

---

## 9. Design-choice FAQ

**Why one clock and a clock enable, instead of just a slow clock?**
Multiple clock domains cause metastability at the boundaries (§2.9) and are hard
to analyze. One global clock + enables keeps the whole chip synchronous and
predictable, which is the entire philosophy the lab hammers on. The enable just
throttles _when things advance_, not _when they're clocked_.

**Why split every button into press and release states?**
A held button reads "pressed" for many ticks. Without a separate release step,
any "if pressed, do X" would fire X repeatedly. Press→wait→release gives exactly
one action per physical press (§2.11).

**Why does the extender machine watch `extender_pos` instead of counting itself?**
Separation of concerns. `Bidir_shift_reg` owns the position (it's the physical
state); SM1 just says "move / stop / which way" and reads back where things are.
The same split shows up in motion: the counter owns `x_pos`, the comparator
judges it, SM only decides. Small dumb blocks + a small smart controller is easier
to get right than one big tangled module.

**Why default every output at the top of the decoder blocks?**
To avoid inferred latches (§2.4). If any path left an output unassigned, the tool
would build a latch to "remember" it, creating a subtle bug. Defaults + a
`default:` case guarantee every output is set on every path.

**Why is `extended` computed from the position rather than the state?**
So it's honest during travel. `extended` should mean "not fully home," which is
`extender_pos != 0000` — true the instant the arm leaves home and all through
extending/retracting, not just in the `EXTENDED` state. Deriving it from the
position captures that directly.

**Why do the counters and shift register saturate/stop at the ends?**
Physically the arm can't go past its limits. Clamping at `0000`/`1111` models the
end stops and prevents wrap-around (F→0), which would look like the arm teleporting.

**Is the mixed blocking/non-blocking in `clocken_generator` a bug?**
It's a code smell (§4.1) that happens to work, inherited from starter code. In
your own clocked blocks, use `<=` everywhere. Don't copy that pattern.

---

## 10. Glossary & cheat-sheet

| Term                 | Plain meaning                                                               |
| -------------------- | --------------------------------------------------------------------------- |
| FPGA                 | A chip whose logic you configure with Verilog                               |
| Verilog              | Language that _describes hardware_ (parallel), not a program (sequential)   |
| `wire`               | A connection; shows whatever drives it; set with `assign`                   |
| `reg`                | A variable assigned in `always`; becomes a flip-flop _only_ if clocked      |
| combinational        | Logic with no memory; output = f(inputs), instant (`assign`, `always @(*)`) |
| sequential           | Logic with memory; updates on a clock edge (`always @(posedge clk)`)        |
| flip-flop / register | 1-bit (or N-bit) memory that samples once per clock tick                    |
| `<=` non-blocking    | Use in clocked blocks; models simultaneous flip-flop updates                |
| `=` blocking         | Use in combinational blocks; executes in order                              |
| clock enable         | A "go" signal that lets clocked logic advance only on certain cycles        |
| metastability        | Undefined flip-flop output when input changes at the clock edge             |
| synchronizer         | Two flip-flops in series that tame an async input                           |
| FSM                  | Finite state machine: register + transition + decoder                       |
| Moore / Mealy        | Outputs from state only / from state **and** inputs                         |
| latch (inferred)     | Accidental memory from leaving a combinational output unassigned            |
| `1'bz`               | High-impedance: the pin drives nothing (floats)                             |
| thermometer code     | `0000,1000,1100,1110,1111` — count by how many top bits are 1               |

**Signal cheat-sheet (who drives what):**

| Signal                                 | From → To                      | Means                                   |
| -------------------------------------- | ------------------------------ | --------------------------------------- |
| `global_clk`                           | GLOBAL buf → everything        | the 50 MHz heartbeat                    |
| `global_clken`                         | clocken_generator → everything | the one-cycle "tick"                    |
| `reset`/`motion`/`extender`/`grappler` | Synch_Inverter2 → FSMs         | clean, active-high controls             |
| `capture_enable`                       | SM → REG_4bit                  | latch the X/Y target now                |
| `x_cnt_en`, `x_cnt_up1_dwn0`           | SM → counter                   | step X / direction                      |
| `x_eq`, `x_lt`, `x_gt`                 | Compx4 → SM                    | position vs target                      |
| `extender_enbl`                        | SM → SM1                       | extender allowed (arm at rest)          |
| `extender_in_motion`, `extender_dir`   | SM1 → shift reg                | shift now / which way                   |
| `extender_pos`                         | shift reg → SM1, leds[5:2]     | how far extended                        |
| `extended`                             | SM1 → SM                       | arm is out (→ fault if you try to move) |
| `grappler_enbl`                        | SM1 → SM2                      | grappler allowed (fully extended)       |
| `grappler_on`                          | SM2 → leds[1]                  | 1 = closed                              |
| `posc_err`                             | SM → leds[0]                   | fault: moved while extended             |

**File map (leaf → root):**

```
Compx1 ─▶ Compx4 ─┐
                  ├─▶ SM ────┐
REG_4bit ─────────┤          │
U_D_Bin_Counter4bit ┘        │
                             ├─ LogicalStep_Lab4_top
Bidir_shift_reg ─▶ SM1 ──────┤
                   SM2 ──────┤
SevenSegment ─▶ segment7_mux ┤
clocken_generator ───────────┤
Synch_Inverter2 ─────────────┘
```

That's the entire design. If you can retell the three walkthroughs in §8 in your
own words and point to which module does each step, you understand this project as
well as whoever wrote it.
