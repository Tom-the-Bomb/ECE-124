// Energy Monitor Control: drives the HVAC unit and the indicator LEDs from the
// comparator flags and the sensor/mode buttons.
// Comparator (comp4x) compares mux_temp (A) vs current_temp (B):
//   i1gti2 = mux>current,  i1eqi2 = mux==current,  i1lti2 = mux<current
module Energy_Monitor_Control (
    input  door_open, window_open, mc_testmode, vac_mode,
    input  i1eqi2, i1gti2, i1lti2,

    output blower_on, ac_on, furnace_on, at_temp,
    output HVAC_run, HVAC_increase, HVAC_decrease,
    output Vacation_led, door_open_led, window_open_led
);
    assign furnace_on = i1gti2;  // leds[0], target above current -> heating
    assign at_temp    = i1eqi2;  // leds[1], target == current
    assign ac_on      = i1lti2;  // leds[2], target below current -> cooling

    // leds[3], blower runs while off-target, unless testing (pb[2]) or sensor open (pb[1]/pb[0])
    assign blower_on = ~i1eqi2 & ~mc_testmode & ~door_open & ~window_open;

    assign window_open_led = window_open;  // leds[4] <- pb[1]
    assign door_open_led   = door_open;    // leds[5] <- pb[0]
    assign Vacation_led    = vac_mode;     // leds[6] <- pb[3]

    // these outputs are inputs (run, increase, decrease) to `hvac.v` (not LEDs).
    // Run only while off-target, and never while
    // test mode (pb[2]), door (pb[0]), or window (pb[1]) is on.
    assign HVAC_run      = ~i1eqi2 & ~door_open & ~window_open & ~mc_testmode;
    assign HVAC_increase = i1gti2;  // count current_temp up   (target above current)
    assign HVAC_decrease = i1lti2;  // count current_temp down (target below current)
endmodule
