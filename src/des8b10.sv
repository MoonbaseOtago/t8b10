//
//	(C) Paul Campbell 2026
//	All Rights Reserved
//


//
//	deserialiser 10->8 with some framing support
//
//	clk is assumed to have been recovered by a PLL from the incoming data stream
//	scrambler is optional 
//
//	output is a 9-bit fifo, written when 'ready' is asserted, support is provided
//		to 'align' packets (force alignment in the fifo) when an end of message k token occurs
//		(so that if the other side of the fifo has a wider read port we 
//		can force the data through)
//

module des8b10(input clk, input reset, input din, 
			   input scramble,
			   output clk10, output reset10, output kout, output [7:0]out, input start_sync, output align, output ready, output synced);

	//
    //  high speed domain 
    //
    //
    //  we're assembling a 10-bit output sequence and use a 1/10 local clock
    //      for most of the logic - note this means that for some paths we have 5/10 (less clk tree and 
    //      skew) of a 1/10 clock setup and for others going the other way 5/10 
    //
    //  Care must be taken - we save lots of gates having to run at full speed at the expense of
    //      more care being taken around timing 
    //
    //  the rising edge os slow clk10 is skewed 2 clks from the start of every outgoing packet
    //
    //      ....|0123456789|0123456789|0123456789|....
    //
    //               ______     ______     ______ 
    //               |    |     |    |     |    | 
    //               |    |     |    |     |    | 
    //            ----    -------    -------    --------
	//
	//	when we see a synchronising symbol in the stream we stretch clock10 carefully so that
	//		there are no runt clocks (as a side effect we miss the next symbol in the stream)
    //

(* gclk *) (* keep *)	reg		 r_clk10;	
	assign clk10 = r_clk10;
	reg		 r_reset;
	assign reset10 = r_reset;
	reg		 r_syncing;
	reg		 r_start_sync;
	reg [9:0]r_d;
	reg [8:0]r_shift;
	reg [4:0]r_count;
	always @(posedge clk) begin
		r_shift <= {din, r_shift[8:1]};
		r_start_sync <= start_sync&!r_syncing&!r_synced;
	end

	reg		 r_synced;
	assign synced = r_synced;

	always @(posedge clk)
    if (reset) begin
        r_count <= 9;
        r_clk10 <= 0;
        r_reset <= 1;
		r_syncing <= 1;
		r_synced <= 0;
    end else
	if (((r_shift[7:0]==8'b01111100) || (r_shift[7:0]==8'b10000011)) && (!r_synced || r_count != 0)) begin
		r_count <= 19;		// wait a clock so we can stretch clk10 cleanly, we'll miss the next symbol
		r_syncing <= 0;
		r_synced <= 1;
	end else begin
		if (r_syncing || r_start_sync) begin
			r_synced <= 0;
			r_syncing <= 1;
		end
        if (r_count == 0) begin
            r_count <= 9;
			r_d <= {din, r_shift[8:0]};
			r_clk10 <= 0;
        end else begin
            case (r_count)
			14:r_clk10 <= 0;
            5: r_clk10 <= 1;
            1: begin r_reset <= 0; end
            default:;
            endcase
            r_count <= r_count - 1;
        end
    end


	

	reg [7:0]kd;
	reg			k;

	wire		err;
	reg			kend;
	reg			r_align;
	assign align = r_align;


	reg			r_rd;
	wire	    sync_found = (r_d[7:0]==8'b01111100 || r_d[7:0]==8'b10000011);
	wire	    sync_set = r_d[7:0]==8'b01111100;

	reg			r_ready;
	assign ready = r_ready;

	always @(posedge clk10)
	if (r_reset || r_syncing) begin
		r_ready <= 0;
		r_align <= 0;
	end else begin
		r_ready <= !k || kd != 8'h1c;	// eat skip
		r_align <= k?kend:err;
	end

	reg [2:0]dh;
	reg derr;
	reg [1:0]rdh, rdl;
	reg [1:0]erdl, erdh;   // 1x means can't confirm rd, 00 means was 0, 01 means was 1

	always @(*) begin
		derr = 0;
		dh = 3'bx;
		rdh = 2'bxx;
		erdh = 2'bxx;
		case (r_d[9:6])
		4'b0000: derr = 1;
		4'b0001: begin dh = 7; rdh = 2'b10; erdh=2'b01; end
		4'b0010: begin dh = 0; rdh = 2'b10; erdh=2'b01; end
		4'b0011: begin dh = 3; rdh = 2'b00; erdh=2'b1x; end
		4'b0100: begin dh = 4; rdh = 2'b10; erdh=2'b01; end
		4'b0101: begin dh = 5; rdh = 2'b00; erdh=2'b1x; end
		4'b0110: begin dh = 6; rdh = 2'b00; erdh=2'b1x; end
		4'b0111: begin dh = 7; rdh = 2'b01; erdh=2'b00; end
		4'b1000: begin dh = 7; rdh = 2'b10; erdh=2'b01; end
		4'b1001: begin dh = 1; rdh = 2'b00; erdh=2'b1x; end
		4'b1010: begin dh = 2; rdh = 2'b00; erdh=2'b1x; end
		4'b1011: begin dh = 4; rdh = 2'b01; erdh=2'b00; end
		4'b1100: begin dh = 3; rdh = 2'b00; erdh=2'b1x; end
		4'b1101: begin dh = 0; rdh = 2'b01; erdh=2'b00; end
		4'b1110: begin dh = 7; rdh = 2'b01; erdh=2'b00; end
		4'b1111: derr = 1;
		endcase
	end

	reg [4:0]dl;
	reg      lerr;
	always @(*) begin
		lerr = 0;
		dl = 5'bx;
		rdl = 2'bxx;
		erdl = 2'bxx;
		case(r_d[5:0])
		6'b00_0000:	lerr = 1;
		6'b00_0001:	lerr = 1;
		6'b00_0010:	lerr = 1;
		6'b00_0011:	lerr = 1;
		6'b00_0100:	lerr = 1;
		6'b00_0101:	begin dl = 15; rdl = 2'b10; erdl=2'b01; end
		6'b00_0110:	begin dl = 0;  rdl = 2'b10; erdl=2'b01; end
		6'b00_0111:	begin dl = 7;  rdl = 2'b00; erdl=2'b00; end

		6'b00_1000:	lerr = 1;
		6'b00_1001:	begin dl = 16; rdl = 2'b10; erdl=2'b01; end
		6'b00_1010:	begin dl = 31; rdl = 2'b10; erdl=2'b01; end
		6'b00_1011:	begin dl = 11; rdl = 2'b00; erdl=2'b1x; end
		6'b00_1100:	begin dl = 24; rdl = 2'b10; erdl=2'b01; end
		6'b00_1101:	begin dl = 13; rdl = 2'b00; erdl=2'b1x; end
		6'b00_1110:	begin dl = 14; rdl = 2'b00; erdl=2'b1x; end
		6'b00_1111:	lerr = 1;

		6'b01_0000:	lerr = 1;
		6'b01_0001:	begin dl = 1;  rdl = 2'b10; erdl=2'b01; end
		6'b01_0010:	begin dl = 2;  rdl = 2'b10; erdl=2'b01; end
		6'b01_0011:	begin dl = 19; rdl = 2'b00; erdl=2'b1x; end
		6'b01_0100:	begin dl = 4;  rdl = 2'b10; erdl=2'b01; end
		6'b01_0101:	begin dl = 21; rdl = 2'b00; erdl=2'b1x; end
		6'b01_0110:	begin dl = 22; rdl = 2'b00; erdl=2'b1x; end
		6'b01_0111:	begin dl = 23; rdl = 2'b01; erdl=2'b00; end

		6'b01_1000:	begin dl = 8;  rdl = 2'b10; erdl=2'b01; end
		6'b01_1001:	begin dl = 25; rdl = 2'b00; erdl=2'b1x; end
		6'b01_1010:	begin dl = 26; rdl = 2'b00; erdl=2'b1x; end
		6'b01_1011:	begin dl = 27; rdl = 2'b01; erdl=2'b00; end
		6'b01_1100:	begin dl = 28; rdl = 2'b00; erdl=2'b1x; end
		6'b01_1101:	begin dl = 29; rdl = 2'b01; erdl=2'b00; end
		6'b01_1110:	begin dl = 30; rdl = 2'b01; erdl=2'b00; end
		6'b01_1111:	lerr = 1;

		6'b10_0000:	lerr = 1;
		6'b10_0001:	begin dl = 30; rdl = 2'b10; erdl=2'b01; end
		6'b10_0010:	begin dl = 29; rdl = 2'b10; erdl=2'b01; end
		6'b10_0011:	begin dl = 3;  rdl = 2'b00; erdl=2'b1x; end
		6'b10_0100:	begin dl = 27; rdl = 2'b10; erdl=2'b01; end
		6'b10_0101:	begin dl = 5;  rdl = 2'b00; erdl=2'b1x; end
		6'b10_0110:	begin dl = 6;  rdl = 2'b00; erdl=2'b1x; end
		6'b10_0111:	begin dl = 8;  rdl = 2'b01; erdl=2'b00; end

		6'b10_1000:	begin dl = 23; rdl = 2'b10; erdl=2'b01; end
		6'b10_1001:	begin dl = 9;  rdl = 2'b00; erdl=2'b1x; end
		6'b10_1010:	begin dl = 10; rdl = 2'b00; erdl=2'b1x; end
		6'b10_1011:	begin dl = 4;  rdl = 2'b01; erdl=2'b00; end
		6'b10_1100:	begin dl = 12; rdl = 2'b00; erdl=2'b1x; end
		6'b10_1101:	begin dl = 2;  rdl = 2'b01; erdl=2'b00; end
		6'b10_1110:	begin dl = 1;  rdl = 2'b01; erdl=2'b00; end
		6'b10_1111:	lerr = 1;

		6'b11_0000:	lerr = 1;
		6'b11_0001:	begin dl = 17; rdl = 2'b00; erdl=2'b1x; end
		6'b11_0010:	begin dl = 18; rdl = 2'b00; erdl=2'b1x; end
		6'b11_0011:	begin dl = 24; rdl = 2'b01; erdl=2'b00; end
		6'b11_0100:	begin dl = 20; rdl = 2'b00; erdl=2'b1x; end
		6'b11_0101:	begin dl = 31; rdl = 2'b01; erdl=2'b00; end
		6'b11_0110:	begin dl = 16; rdl = 2'b01; erdl=2'b00; end
		6'b11_0111:	lerr = 1;

		6'b11_1000:	begin dl = 7;  rdl = 2'b00; erdl=2'b01; end
		6'b11_1001:	begin dl = 0;  rdl = 2'b01; erdl=2'b00; end
		6'b11_1010:	begin dl = 15; rdl = 2'b01; erdl=2'b00; end
		6'b11_1011:	lerr = 1;
		6'b11_1100:	lerr = 1;
		6'b11_1101:	lerr = 1;
		6'b11_1110:	lerr = 1;
		6'b11_1111:	lerr = 1;
		endcase
	end

	reg krd;
	always @(*) begin
		k = 1;
		case (r_d)
		10'b0010_111100: begin kend = 0; kd = 8'h1c;    krd = 0;end
		10'b1101_000011: begin kend = 0; kd = 8'h1c;	krd = 0;end // k28.0	SKP
		10'b1001_111100: begin kend = 0; kd = 8'h3c;    krd = 1;end
		10'b0110_000011: begin kend = 0; kd = 8'h3c;	krd = 1;end // k28.1	FTS
		10'b1010_111100: begin kend = 0; kd = 8'h5c;    krd = 1;end
		10'b0101_000011: begin kend = 0; kd = 8'h5c;	krd = 1;end // k28.2	SDP
		10'b1100_111100: begin kend = 0; kd = 8'h7c;    krd = 1;end
		10'b0011_000011: begin kend = 0; kd = 8'h7c;	krd = 1;end // k28.3	IDL
		10'b0100_111100: begin kend = 0; kd = 8'h9c;    krd = 0;end
		10'b1011_000011: begin kend = 0; kd = 8'h9c;	krd = 0;end // k28.4	-
		10'b0101_111100: begin kend = 0; kd = 8'hbc;    krd = 1;end
		10'b1010_000011: begin kend = 0; kd = 8'hbc;	krd = 1;end // k28.5	COM
		10'b0110_111100: begin kend = 0; kd = 8'hdc;    krd = 1;end 
		10'b1001_000011: begin kend = 0; kd = 8'hdc;	krd = 1;end // k28.6	-
		10'b0001_111100: begin kend = 1; kd = 8'hfc;    krd = 0;end
		10'b1110_000011: begin kend = 1; kd = 8'hfc;	krd = 0;end // k28.7	EIE
		10'b0001_010111: begin kend = 0; kd = 8'hf7;    krd = 0;end
		10'b1110_101000: begin kend = 0; kd = 8'hf7;	krd = 0;end // k23.7	PAD
		10'b0001_011011: begin kend = 0; kd = 8'hfb;    krd = 0;end
		10'b1110_100100: begin kend = 0; kd = 8'hfb;	krd = 0;end // k27.7	STP
		10'b0001_011101: begin kend = 1; kd = 8'hfd;    krd = 0;end
		10'b1110_100010: begin kend = 1; kd = 8'hfd;	krd = 0;end // k29.7	END
		10'b0001_011110: begin kend = 1; kd = 8'hfe;    krd = 0;end
		10'b1110_100001: begin kend = 1; kd = 8'hfe;	krd = 0;end // k30.7	EDB
		default: begin
				k = 0;
				kend = 1'bx;
				kd = 8'bx;
				krd = 1'bx;
			 end
		endcase
	end


	wire [7:0]lfsr_out;
	wire lfsr_reset;
	wire lfsr_shift;
	lfsr8b10b lfsr(.clk(clk10), .rst(lfsr_reset), .shift(lfsr_shift), .out(lfsr_out));

	assign lfsr_reset = (r_reset || (sync_found) && k && kd == 8'hbc);	   		// COM
	assign lfsr_shift = (!r_reset && (!(k && kd == 8'h1c)));	// SKP


	always @(posedge clk10)
	if (r_reset || (r_syncing && sync_found)) begin
		r_rd <= sync_set;
	end else
	if (!r_syncing) begin
		if (k) begin
			if (krd) r_rd <= ~r_rd;
		end else
		casez ({rdh, rdl})
		4'b00_01,
		4'b01_00: r_rd <= 1;
		4'b10_00,
		4'b00_10: r_rd <= 0;
		default:
			;
		endcase
	end else begin
		r_rd <= sync_set;
	end

	reg[7:0]r_out;
	assign out = r_out;
	reg	r_k;
	assign kout = r_k;

	assign err = derr || lerr || (rdh[0]&rdl[0]) || (rdh[1]&rdl[1]) || (~erdl[1])?(r_rd != erdl[0]):erdh[1]?0:(r_rd != erdh[0]);

	always @(posedge clk10)
	if (!r_syncing) begin
		if (k) begin
			r_out <= kd;
			r_k <= 1;
		end else
		if (err) begin
			r_out <= 0;	// made up symbol for error
			r_k <= 1;
		end else begin
			if (~scramble) begin
				r_out <= {dh, dl};
			end else begin
				r_out <= {dh, dl}^lfsr_out;
			end
			r_k <= 0;
		end
	end

	

endmodule

/* For Emacs:
 * Local Variables:
 * mode:c
 * indent-tabs-mode:t
 * tab-width:4
 * c-basic-offset:4
 * End:
 * For VIM:
 * vim:set softtabstop=4 shiftwidth=4 tabstop=4:
 */
