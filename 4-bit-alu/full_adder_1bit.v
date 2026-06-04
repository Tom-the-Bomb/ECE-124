module full_adder_1bit (
    input  input_A, input_B,
    input  carry_in,
    output carry_out, sum_out
);

    wire half_sum_out, half_carry_out;

    assign half_sum_out   = input_A ^ input_B;
    assign half_carry_out = input_A & input_B;

    assign carry_out = half_carry_out | (half_sum_out & carry_in);  // carry = majority(A, B, cin)
    assign sum_out   = half_sum_out ^ carry_in;

endmodule
