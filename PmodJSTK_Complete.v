`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Complete PmodJSTK controller - All modules integrated into one file
// Outputs: joystick direction signals and button press
//////////////////////////////////////////////////////////////////////////////////

// ==============================================================================
// 							Top Module - PmodJSTK Demo
// ==============================================================================
module PmodJSTK_Demo(
    CLK,
    RST,
    MISO,
    SS,
    MOSI,
    SCLK,
    joystick_up,
    joystick_down,
    joystick_left,
    joystick_right,
    joystick_pressed,
	joystick_left_raw,
	joystick_right_raw
    );

	// Port Declarations
	input CLK;					// 100MHz onboard clock
	input RST;					// Reset button
	input MISO;					// Master In Slave Out, Pin 3, Port JA
	output SS;					// Slave Select, Pin 1, Port JA
	output MOSI;				// Master Out Slave In, Pin 2, Port JA
	output SCLK;				// Serial Clock, Pin 4, Port JA
	output joystick_up;		// Joystick pushed up
	output joystick_down;	// Joystick pushed down
	output joystick_left;	// Joystick pushed left
	output joystick_right;	// Joystick pushed right
	output joystick_pressed; // Joystick button pressed
	output joystick_left_raw;  // Raw left signal (no one-pulse)
	output joystick_right_raw; // Raw right signal (no one-pulse)

	// Internal signals
	wire SS;
	wire MOSI;
	wire SCLK;
	wire [7:0] sndData;
	wire sndRec;
	wire [39:0] jstkData;
	wire [9:0] x_pos;
	wire [9:0] y_pos;
	
	// Threshold for direction detection
	parameter THRESHOLD = 100;
	parameter CENTER = 512;

	// PmodJSTK Interface
	PmodJSTK PmodJSTK_Int(
		.CLK(CLK),
		.RST(RST),
		.sndRec(sndRec),
		.DIN(sndData),
		.MISO(MISO),
		.SS(SS),
		.SCLK(SCLK),
		.MOSI(MOSI),
		.DOUT(jstkData)
	);

	// Send Receive Generator (5Hz polling)
	ClkDiv_5Hz genSndRec(
		.CLK(CLK),
		.RST(RST),
		.CLKOUT(sndRec)
	);

	// Extract X and Y positions from joystick data
	assign x_pos = {jstkData[9:8], jstkData[23:16]};    // X: 0-1023
	assign y_pos = {jstkData[25:24], jstkData[39:32]};  // Y: 0-1023

	// Direction detection (raw signals)
	wire joystick_down_raw    = (y_pos > CENTER + THRESHOLD + 80);  // Y > 612+80
	wire joystick_up_raw  = (y_pos < CENTER - THRESHOLD);  // Y < 412
	assign joystick_right_raw = (x_pos > CENTER + THRESHOLD);  // X > 612
	assign joystick_left_raw  = (x_pos < CENTER - THRESHOLD);  // X < 412
	wire joystick_pressed_raw = jstkData[0];
	
	// One-pulse modules for each direction and button
	one_pulse op_up(
		.clk(CLK),
		.rst(RST),
		.in(joystick_up_raw),
		.out(joystick_up)
	);
	
	one_pulse op_down(
		.clk(CLK),
		.rst(RST),
		.in(joystick_down_raw),
		.out(joystick_down)
	);
	
	one_pulse op_left(
		.clk(CLK),
		.rst(RST),
		.in(joystick_left_raw),
		.out(joystick_left)
	);
	
	one_pulse op_right(
		.clk(CLK),
		.rst(RST),
		.in(joystick_right_raw),
		.out(joystick_right)
	);
	
	one_pulse op_pressed(
		.clk(CLK),
		.rst(RST),
		.in(joystick_pressed_raw),
		.out(joystick_pressed)
	);

	// Data to be sent to PmodJSTK (no LEDs to control)
	assign sndData = 8'h00;

endmodule


// ==============================================================================
// 								PmodJSTK Main Interface
// ==============================================================================
module PmodJSTK(
	CLK,
	RST,
	sndRec,
	DIN,
	MISO,
	SS,
	SCLK,
	MOSI,
	DOUT
);

	// Port Declarations
	input CLK;						// 100MHz onboard clock
	input RST;						// Reset
	input sndRec;					// Send receive, initializes data read/write
	input [7:0] DIN;				// Data that is to be sent to the slave
	input MISO;						// Master in slave out
	output SS;						// Slave select, active low
	output SCLK;					// Serial clock
	output MOSI;					// Master out slave in
	output [39:0] DOUT;			// All data read from the slave

	// Internal signals
	wire SS;
	wire SCLK;
	wire MOSI;
	wire [39:0] DOUT;
	wire getByte;
	wire [7:0] sndData;
	wire [7:0] RxData;
	wire BUSY;
	wire iSCLK;		// Internal serial clock

	// SPI Controller
	spiCtrl SPI_Ctrl(
		.CLK(iSCLK),
		.RST(RST),
		.sndRec(sndRec),
		.BUSY(BUSY),
		.DIN(DIN),
		.RxData(RxData),
		.SS(SS),
		.getByte(getByte),
		.sndData(sndData),
		.DOUT(DOUT)
	);

	// SPI Mode 0
	spiMode0 SPI_Int(
		.CLK(iSCLK),
		.RST(RST),
		.sndRec(getByte),
		.DIN(sndData),
		.MISO(MISO),
		.MOSI(MOSI),
		.SCLK(SCLK),
		.BUSY(BUSY),
		.DOUT(RxData)
	);

	// Serial Clock Generator
	ClkDiv_66_67kHz SerialClock(
		.CLK(CLK),
		.RST(RST),
		.CLKOUT(iSCLK)
	);

endmodule


// ==============================================================================
// 								SPI Controller
// ==============================================================================
module spiCtrl(
	CLK,
	RST,
	sndRec,
	BUSY,
	DIN,
	RxData,
	SS,
	getByte,
	sndData,
	DOUT
);

	// Port Declarations
	input CLK;						// 66.67kHz onboard clock
	input RST;						// Reset
	input sndRec;					// Send receive, initializes data read/write
	input BUSY;						// If active data transfer currently in progress
	input [7:0] DIN;				// Data that is to be sent to the slave
	input [7:0] RxData;			// Last data byte received
	output SS;						// Slave select, active low
	output getByte;				// Initiates a data transfer in SPI_Int
	output [7:0] sndData;		// Data that is to be sent to the slave
	output [39:0] DOUT;			// All data read from the slave

	// Internal registers
	reg SS = 1'b1;
	reg getByte = 1'b0;
	reg [7:0] sndData = 8'h00;
	reg [39:0] DOUT = 40'h0000000000;

	// FSM States
	parameter [2:0] Idle = 3'd0,
						 Init = 3'd1,
						 Wait = 3'd2,
						 Check = 3'd3,
						 Done = 3'd4;
	
	reg [2:0] pState = Idle;
	reg [2:0] byteCnt = 3'd0;
	parameter byteEndVal = 3'd5;
	reg [39:0] tmpSR = 40'h0000000000;

	// FSM Implementation
	always @(negedge CLK) begin
		if(RST == 1'b1) begin
			SS <= 1'b1;
			getByte <= 1'b0;
			sndData <= 8'h00;
			tmpSR <= 40'h0000000000;
			DOUT <= 40'h0000000000;
			byteCnt <= 3'd0;
			pState <= Idle;
		end
		else begin
			case(pState)
				Idle : begin
					SS <= 1'b1;
					getByte <= 1'b0;
					sndData <= 8'h00;
					tmpSR <= 40'h0000000000;
					DOUT <= DOUT;
					byteCnt <= 3'd0;
					if(sndRec == 1'b1) begin
						pState <= Init;
					end
					else begin
						pState <= Idle;
					end
				end

				Init : begin
					SS <= 1'b0;
					getByte <= 1'b1;
					sndData <= DIN;
					tmpSR <= tmpSR;
					DOUT <= DOUT;
					if(BUSY == 1'b1) begin
						pState <= Wait;
						byteCnt <= byteCnt + 1'b1;
					end
					else begin
						pState <= Init;
					end
				end

				Wait : begin
					SS <= 1'b0;
					getByte <= 1'b0;
					sndData <= sndData;
					tmpSR <= tmpSR;
					DOUT <= DOUT;
					byteCnt <= byteCnt;
					if(BUSY == 1'b0) begin
						pState <= Check;
					end
					else begin
						pState <= Wait;
					end
				end

				Check : begin
					SS <= 1'b0;
					getByte <= 1'b0;
					sndData <= sndData;
					tmpSR <= {tmpSR[31:0], RxData};
					DOUT <= DOUT;
					byteCnt <= byteCnt;
					if(byteCnt == 3'd5) begin
						pState <= Done;
					end
					else begin
						pState <= Init;
					end
				end

				Done : begin
					SS <= 1'b1;
					getByte <= 1'b0;
					sndData <= 8'h00;
					tmpSR <= tmpSR;
					DOUT[39:0] <= tmpSR[39:0];
					byteCnt <= byteCnt;
					if(sndRec == 1'b0) begin
						pState <= Idle;
					end
					else begin
						pState <= Done;
					end
				end

				default : pState <= Idle;
			endcase
		end
	end

endmodule


// ==============================================================================
// 								SPI Mode 0
// ==============================================================================
module spiMode0(
    CLK,
    RST,
    sndRec,
    DIN,
    MISO,
    MOSI,
    SCLK,
    BUSY,
    DOUT
);

	// Port Declarations
	input CLK;						// 66.67kHz serial clock
	input RST;						// Reset
	input sndRec;					// Send receive, initializes data read/write
	input [7:0] DIN;				// Byte that is to be sent to the slave
	input MISO;						// Master input slave output
	output MOSI;					// Master out slave in
	output SCLK;					// Serial clock
	output BUSY;					// Busy if sending/receiving data
	output [7:0] DOUT;			// Current data byte read from the slave

	// Internal signals
	wire MOSI;
	wire SCLK;
	wire [7:0] DOUT;
	reg BUSY;

	// FSM States
	parameter [1:0] Idle = 2'd0,
						 Init = 2'd1,
						 RxTx = 2'd2,
						 Done = 2'd3;

	reg [4:0] bitCount;
	reg [7:0] rSR = 8'h00;
	reg [7:0] wSR = 8'h00;
	reg [1:0] pState = Idle;
	reg CE = 0;

	// Serial clock output
	assign SCLK = (CE == 1'b1) ? CLK : 1'b0;
	assign MOSI = wSR[7];
	assign DOUT = rSR;

	// Write Shift Register
	always @(negedge CLK) begin
		if(RST == 1'b1) begin
			wSR <= 8'h00;
		end
		else begin
			case(pState)
				Idle : begin
					wSR <= DIN;
				end
				Init : begin
					wSR <= wSR;
				end
				RxTx : begin
					if(CE == 1'b1) begin
						wSR <= {wSR[6:0], 1'b0};
					end
				end
				Done : begin
					wSR <= wSR;
				end
			endcase
		end
	end

	// Read Shift Register
	always @(posedge CLK) begin
		if(RST == 1'b1) begin
			rSR <= 8'h00;
		end
		else begin
			case(pState)
				Idle : begin
					rSR <= rSR;
				end
				Init : begin
					rSR <= rSR;
				end
				RxTx : begin
					if(CE == 1'b1) begin
						rSR <= {rSR[6:0], MISO};
					end
				end
				Done : begin
					rSR <= rSR;
				end
			endcase
		end
	end

	// SPI Mode 0 FSM
	always @(negedge CLK) begin
		if(RST == 1'b1) begin
			CE <= 1'b0;
			BUSY <= 1'b0;
			bitCount <= 4'h0;
			pState <= Idle;
		end
		else begin
			case (pState)
				Idle : begin
					CE <= 1'b0;
					BUSY <= 1'b0;
					bitCount <= 4'd0;
					if(sndRec == 1'b1) begin
						pState <= Init;
					end
					else begin
						pState <= Idle;
					end
				end

				Init : begin
					BUSY <= 1'b1;
					bitCount <= 4'h0;
					CE <= 1'b0;
					pState <= RxTx;
				end

				RxTx : begin
					BUSY <= 1'b1;
					bitCount <= bitCount + 1'b1;
					if(bitCount >= 4'd8) begin
						CE <= 1'b0;
					end
					else begin
						CE <= 1'b1;
					end
					if(bitCount == 4'd8) begin
						pState <= Done;
					end
					else begin
						pState <= RxTx;
					end
				end

				Done : begin
					CE <= 1'b0;
					BUSY <= 1'b1;
					bitCount <= 4'd0;
					pState <= Idle;
				end

				default : pState <= Idle;
			endcase
		end
	end

endmodule


// ==============================================================================
// 						Clock Divider 66.67kHz
// ==============================================================================
module ClkDiv_66_67kHz(
    CLK,
    RST,
    CLKOUT
);

	input CLK;
	input RST;
	output CLKOUT;

	reg CLKOUT = 1'b1;
	parameter cntEndVal = 10'b1011101110;
	reg [9:0] clkCount = 10'b0000000000;

	always @(posedge CLK) begin
		if(RST == 1'b1) begin
			CLKOUT <= 1'b0;
			clkCount <= 10'b0000000000;
		end
		else begin
			if(clkCount == cntEndVal) begin
				CLKOUT <= ~CLKOUT;
				clkCount <= 10'b0000000000;
			end
			else begin
				clkCount <= clkCount + 1'b1;
			end
		end
	end

endmodule


// ==============================================================================
// 						Clock Divider 5Hz
// ==============================================================================
module ClkDiv_5Hz(
    CLK,
    RST,
    CLKOUT
);

	input CLK;
	input RST;
	output CLKOUT;

	reg CLKOUT;
	parameter cntEndVal = 24'h989680;
	reg [23:0] clkCount = 24'h000000;

	always @(posedge CLK) begin
		if(RST == 1'b1) begin
			CLKOUT <= 1'b0;
			clkCount <= 24'h000000;
		end
		else begin
			if(clkCount == cntEndVal) begin
				CLKOUT <= ~CLKOUT;
				clkCount <= 24'h000000;
			end
			else begin
				clkCount <= clkCount + 1'b1;
			end
		end
	end

endmodule


// ==============================================================================
// 							One Pulse Module
// ==============================================================================
module one_pulse(
	input wire clk,
	input wire rst,
	input wire in,
	output reg out
);

	reg in_delay;
	reg rst_done;  // Track if reset just completed
	
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			in_delay <= 1'b0;
			out <= 1'b0;
			rst_done <= 1'b0;
		end else begin
			if (!rst_done) begin
				// First cycle after reset: sync in_delay without generating pulse
				in_delay <= in;
				out <= 1'b0;
				rst_done <= 1'b1;
			end else begin
				// Normal operation
				in_delay <= in;
				out <= in & ~in_delay;
			end
		end
	end

endmodule
