/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_8b10 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

	reg r_reset;
	reg r_scramble;
	always @(posedge clk)
		r_reset <= ~rst_n;

	always @(posedge clk)
	if (~rst_n)
		r_scramble <= ui_in[0];



	assign uio_out[0] = 0;
	assign uio_out[4] = 0;
	assign uio_oe = 8'b1110_1110;
	wire x1, x2, x3;
	ser8b10 s8b10(.clk(clk), .reset(r_reset), .dout(uio_out[2]),
			      .scramble(r_scramble),
			      .clk10(uio_out[6]), .reset10(x1), .k(uio_in[0]), .in(ui_in), .ready(uio_in[4]));

	des8b10 d10b8(.clk(clk), .reset(r_reset), 
			 .scramble(r_scramble),
			.kout(uio_out[1]), .out(uo_out), .start_sync(1'b1),
			.din(uio_out[2]), 

			.clk10(uio_out[5]), .reset10(x2), .align(x3),
			.ready(uio_out[3]), .synced(uio_out[7]));

	  wire _unused = &{ena, x1, x2, x3, uio_in[7:5], uio_in[3:1], 1'b0};
endmodule
