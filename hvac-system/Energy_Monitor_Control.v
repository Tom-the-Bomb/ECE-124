module Energy_Monitor_Control (
   input door_open, window_open, mc_testmode, vac_mode,
   input i1eqi2,i1gti2,i1lti2,

	output blower_on, ac_on, furnace_on, at_temp,
	output HVAC_run, HVAC_increase, HVAC_decrease,
	output vacation_led, door_open_led, window_open_led
);
	assign ac_on = i1lti2;
	assign furnace_on = i1gti2;
	assign at_temp = i1eqi2;
	assign vacation_led = vac_mode;
	assign door_open_led = door_open;
	assign window_open_led = window_open;

	assign HVAC_run = ~i1eqi2 & ~door_open & ~window_open & ~mc_testmode;
	assign HVAC_increase = i1gti2;
	assign HVAC_decrease = i1lti2;
	assign blower_on = ~i1eqi2 & ~mc_testmode & ~door_open & ~window_open;

endmodule
