`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    //$dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  reg done=0;
  reg fail = 0;
  wire rcv_clk = uio_out[5];

  // Replace tt_um_example with your module name:
  tt_um_8b10 user_project (
    `ifdef GL_TEST
        .VPWR( 1'b1),     
        .VGND( 1'b0),
    `endif
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

	initial #1000000 $finish;
	initial begin
		clk = 0;
		forever #10 clk = ~clk;
	end
	initial begin
		#1
		ui_in <= 1; // turn on scrambling
		rst_n <= 0;
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		rst_n <= 1;
	end
	integer i = 0;
	integer j = 0;
	initial begin
		uio_in[4] <= 0;
		@(posedge rst_n);
		@(posedge uio_out[6]);
		@(posedge uio_out[6]);
		uio_in[4] <= 1;
		uio_in[0] <= 1;
		ui_in = 8'hbc;
		@(posedge uio_out[6]);
		@(posedge uio_out[6]);
		@(posedge uio_out[6]);
		@(posedge uio_out[6]);
		@(posedge uio_out[6]);
		@(posedge uio_out[6]);
		uio_in[4] <= 0;
		@(posedge uio_out[6]);
		uio_in[4] <= 1;
		uio_in[0] <= 0;
		for (i = 0; i < 256; i=i+1) begin
			ui_in = i[7:0];
			@(posedge uio_out[6]);
		end
		uio_in[4] <= 0;
	end

	always @(posedge uio_out[5])
	if (uio_out[3]) begin
		if (uo_out != j[7:0]) begin
			$display("fail!");
			done = 1;
			fail = 1;
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			$finish;
		end
		j = j+1;
		if (j == 256) begin
			$display("ok");
			done = 1;
			fail = 0;
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			@(posedge uio_out[5]);
			$finish;
		end
	end
	
	

endmodule
