`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: top
// Description: Top level module for SPI LCD display controller
//////////////////////////////////////////////////////////////////////////////////
module top(
    input wire clk,           // System clock (100MHz from Basys3)
    input wire rst,         // Reset signal (active high)
    output wire SCLK,         // SPI clock
    output wire MOSI,         // SPI data (Master Out Slave In)
    output wire RES,          // LCD reset
    output wire SS,           // SPI chip select
    output wire BC,           // LCD backlight/DC control
    output wire DC,           // SPI data (Master In Slave Out) - unused but in XDC
    // Joystick SPI interface
    input wire JSTK_MISO,     // Joystick MISO
    output wire JSTK_SS,      // Joystick S
    

    output wire JSTK_MOSI,    // Joystick MOSI
    output wire JSTK_SCLK,     // Joystick SCLK
    // Sonic sensor interface
    input wire Echo,          // Sonic sensor echo
    output wire Trig,         // Sonic sensor trigger
    output reg [15:0] LED,
    output wire [6:0] DISPLAY,
    output wire [3:0] DIGIT
);
    
    // Internal signals for LCD pixel data
    wire [15:0] ram_lcd_data;
    wire [7:0] ram_lcd_addr_x;
    wire [7:0] ram_lcd_addr_y;
    
    // Clock divider: 100MHz -> 10MHz
    reg [2:0] clk_div_counter = 0;
    reg clk_divided = 0;

    reg [15:0] distance_display;
    wire [19:0] distance;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_div_counter <= 0;
            clk_divided <= 0;
        end else begin
            if (clk_div_counter == 4) begin  // Divide by 10: 100MHz/10 = 10MHz
                clk_div_counter <= 0;
                clk_divided <= ~clk_divided;
            end else begin
                clk_div_counter <= clk_div_counter + 1;
            end
        end
    end
    
    // Instantiate the spi_lcd module
    spi_lcd #(
        .LCD_W(8'd132),
        .LCD_H(8'd162)
    ) lcd_inst (
        .clk(clk),
        .rst(rst),
        .ram_lcd_data(ram_lcd_data),
        .ram_lcd_addr_x(ram_lcd_addr_x),
        .ram_lcd_addr_y(ram_lcd_addr_y),
        .lcd_rst_n_out(RES),
        .lcd_bl_out(BC),
        .lcd_dc_out(DC),              // Not connected to external pin
        .lcd_clk_out(SCLK),
        .lcd_data_out(MOSI),
        .lcd_cs_n_out(SS)
    );
    // Joystick signals
    wire joystick_up, joystick_down, joystick_left, joystick_right, joystick_pressed, joystick_left_raw, joystick_right_raw;

    // Sonic sensor signal
    wire touch;

    PmodJSTK_Demo joystick(
        .CLK(clk),
        .RST(rst),
        .MISO(JSTK_MISO),
        .SS(JSTK_SS),
        .MOSI(JSTK_MOSI),
        .SCLK(JSTK_SCLK),
        .joystick_up(joystick_up),
        .joystick_down(joystick_down),
        .joystick_left(joystick_left),
        .joystick_right(joystick_right),
        .joystick_pressed(joystick_pressed),
        .joystick_left_raw(joystick_left_raw),
        .joystick_right_raw(joystick_right_raw)
    );

    // Instantiate sonic sensor module
    sonic_top sonic(
        .clk(clk),
        .rst(rst),
        .Echo(Echo),
        .Trig(Trig),
        .touch(touch),
        .dis(distance)
    );
	wire clk_25MHz, clk_26, clk_23;
    wire clk_WALK;
    wire clk_animation;
    wire clk_water;
    wire clk_GAME_capy_move;
    wire clk_ball_speed;
	clock_divider #(.n(2)) clk_div_inst (
		.clk(clk),
		.clk_div(clk_25MHz)
	);
	clock_divider #(.n(26)) clk_1sec (
		.clk(clk),
		.clk_div(clk_26)
	);
    clock_divider #(.n(24)) WALK_speed (
		.clk(clk),
		.clk_div(clk_WALK)
	);
	clock_divider #(.n(25)) animation_freq (
		.clk(clk),
		.clk_div(clk_animation)
	);
	clock_divider #(.n(22)) water_freq (
		.clk(clk),
		.clk_div(clk_water)
	);
    clock_divider #(.n(21)) GAME_capy_freq (
		.clk(clk),
		.clk_div(clk_GAME_capy_move)
	);
    clock_divider #(.n(23)) clk_23_freq (
		.clk(clk),
		.clk_div(clk_23)
	);
    clock_divider #(.n(22)) GAME_ball_speed (
		.clk(clk),
		.clk_div(clk_ball_speed)
	);
	// Calculate image address based on LCD coordinates (rotated 90 degrees)
	// Swap x and y, then flip: Display(x,y) -> Image(y, 131-x)
	// Add vertical offset to shift image up
	// parameter Y_OFFSET = 8'd25;  // Adjust this value to move image up/down
	wire [7:0] rotated_x;
	wire [7:0] rotated_y;
    reg Direction;
    parameter WALK_RIGHT = 1'b0;
    parameter WALK_LEFT = 1'b1;
	assign rotated_x = 8'd161 - ram_lcd_addr_y;  
	assign rotated_y = ram_lcd_addr_x;  
	wire [7:0] x = rotated_x >> 1; // Divide by 2
	wire [7:0] y = rotated_y >> 1; // Divide by 2
	reg [7:0] capy_offset_x;
    wire [7:0] capy_offset_y = 8'd15;
    wire [7:0] capy_img_x = x - capy_offset_x;
    wire [7:0] capy_img_y = y - capy_offset_y;
    wire [7:0] capy_img_x_final = (Direction == WALK_RIGHT) ? 8'd40 - capy_img_x : capy_img_x;
    wire [7:0] capy_img_y_final = capy_img_y;
    wire [20:0] capy_img_addr = capy_img_y_final * 8'd41 + capy_img_x_final;
    wire [9:0] heart_addr = (x % 10) + (y-1) * 10;
    wire [9:0] chicken_addr = ((x % 10) - 1 + (y-1) * 10);
    wire [9:0] menu_addr = (x % 27) + (y-48) * 27;
    reg [9:0] poop_addr_cal; 
    always @* begin
        if (x >= 15 && x < 25 && y >= 54 && y < 64) begin
            poop_addr_cal = (x - 15) + (y - 54) * 10;
        end else if (x >= 32 && x < 42 && y >= 48 && y < 58) begin
            poop_addr_cal = (x - 32) + (y - 48) * 10;
        end else if (x >= 65 && x < 75 && y >= 51 && y < 61) begin
            poop_addr_cal = (x - 65) + (y - 51) * 10;
        end else begin
            poop_addr_cal = 0;
        end
    end
    wire [9:0] poop_addr = poop_addr_cal;
    reg [15:0] pooping_scene_addr_cal;
    wire [15:0] pooping_scene_addr = pooping_scene_addr_cal;
    always @* begin
        if (x >= 13 && x < 67 && y >= 11 && y < 55) begin
            pooping_scene_addr_cal = (x-13) + (y-11) * 54;
        end else begin
            pooping_scene_addr_cal = 0; 
        end
    end
    reg [15:0] GAMEEND_scene_addr_cal;
    wire [15:0] GAMEEND_scene_addr = GAMEEND_scene_addr_cal;
    always @* begin
        if (x >= 13 && x < 67 && y >= 11 && y < 55) begin
            GAMEEND_scene_addr_cal = (x-13) + (y-11) * 54;
        end else begin
            GAMEEND_scene_addr_cal = 0; 
        end
    end
    wire [15:0] hotspring_scene_addr = GAMEEND_scene_addr;
    reg [7:0] water_offset;
    wire [15:0] water_addr = (x - water_offset) + (y-48) * 81;
    reg [7:0] GAME_capy_offset_x; 
    wire [7:0] GAME_capy_offset_y = 44;
    reg [7:0] GAME_ball_offset_x, GAME_ball_offset_y;
    wire [9:0] ball_addr = (x - GAME_ball_offset_x) + (y - GAME_ball_offset_y) * 10;
    wire [9:0] spin_addr = (x - GAME_capy_offset_x) + (y-44) * 27;
    wire [9:0] weather_addr = (x - 33) + y * 15;
    reg [2:0] capy_state, next_capy_state, capy_prev_state;
    reg [1:0] lowscreen_state, next_lowscreen_state;
    reg [2:0] scene, next_scene;
    reg [2:0] event_select, food_select;
    parameter CAPY_IDLE = 3'd0;
    parameter CAPY_WALK = 3'd1;
    parameter CAPY_SLEEP = 3'd2;
    parameter CAPY_FEED = 3'd3;
    parameter CAPY_TOUCH = 3'd4;
    parameter LOWSCREEN_INIT = 3'd0;
    parameter LOWSCREEN_MENU = 3'd1;
    parameter LOWSCREEN_CLEAN = 3'd2;
    parameter LOWSCREEN_SELECTFOOD = 3'd3;
    parameter SCENE_DEFAULT = 3'd0;
    parameter SCENE_POOPING = 3'd1;
    parameter SCENE_PLAY = 3'd2;
    parameter SCENE_GAMEOVER = 3'd3;
    parameter SCENE_SICK = 3'd4;
    parameter SCENE_HOTSPRING = 3'd5;
    reg [2:0] sec_counter_IDLE;
    reg [2:0] sec_counter_WALK;
    reg [2:0] sec_counter_SLEEP;
    reg [2:0] sec_counter_FEED;
    reg [2:0] sec_counter_POOPSCENE;
    reg [2:0] sec_counter_GAME_END;
    reg[3:0] sec_counter_DEFAULT_SCENE;
    reg [2:0] life, chicken;
    reg[1:0] poop_count;
    reg prev_feed;
    wire cur_feed = (capy_state == CAPY_FEED);
    wire feed_end = prev_feed & ~cur_feed;
    reg prev_feed_1sec;
    wire cur_feed_1sec = (capy_state == CAPY_FEED);
    wire feed_end_1sec = prev_feed_1sec & ~cur_feed_1sec;
    reg weather; // 0: sun 1: cold
    reg weather_enter_feed;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            weather_enter_feed <= 0;
        end else begin
            if (~prev_feed && cur_feed) begin
                weather_enter_feed <= weather;
            end else begin
                weather_enter_feed <= weather_enter_feed;
            end 
        end
    end
    
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            weather <= 0;
        end else begin
            if (sec_counter_DEFAULT_SCENE >= 10) begin
                weather <= ~weather;
            end else begin
                weather <= weather;
            end
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prev_feed <= 0;
        end else begin
            prev_feed <= cur_feed;
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            prev_feed_1sec <= 0;
        end else begin
            prev_feed_1sec <= cur_feed_1sec;
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            chicken <= 3'b111;
        end else begin
            if (scene == SCENE_SICK) begin
                chicken <= 3'b111;
            end else if (feed_end_1sec) begin
                chicken <= 3'b111;
            end else if (scene == SCENE_DEFAULT) begin
                if (sec_counter_DEFAULT_SCENE == 7) begin
                    chicken <= chicken << 1;
                end else begin
                    chicken <= chicken;
                end
            end else begin
                chicken <= chicken;
            end
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            life <= 3'b111;
        end else begin
            if (scene == SCENE_SICK) begin
                life <= 3'b111;
            end else if (feed_end_1sec && chicken != 3'b000) begin
                life[2] <= 1;
                life[1:0] <= life[2:1];
            end else if (scene == SCENE_DEFAULT) begin
                if (sec_counter_DEFAULT_SCENE == 7 && chicken == 3'b000) begin
                    life <= life << 1;
                end else begin
                    life <= life;
                end
            end else begin
                life <= life;
            end
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            poop_count <= 0;
        end else begin
            if (poop_count < 3 && feed_end) begin
                poop_count <= poop_count + 1;
            end else if (lowscreen_state == LOWSCREEN_CLEAN && water_offset <= 2) begin
                poop_count <= 0;
            end
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            sec_counter_IDLE <= 0;
        end else begin
            if (capy_state == CAPY_IDLE) begin
                if (sec_counter_IDLE >= 3'd5) begin
                    sec_counter_IDLE <= 0;
                end else begin
                    sec_counter_IDLE <= sec_counter_IDLE + 1;
                end
            end else begin
                sec_counter_IDLE <= 0;
            end
            
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            sec_counter_WALK <= 0;
        end else begin
            if (capy_state == CAPY_WALK) begin
                if (sec_counter_WALK >= 3'd5) begin
                    sec_counter_WALK <= 0;
                end else begin
                    sec_counter_WALK <= sec_counter_WALK + 1;
                end
            end else begin
                sec_counter_WALK <= 0;
            end
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            sec_counter_SLEEP <= 0;
        end else begin
            if (capy_state == CAPY_SLEEP) begin
                if (sec_counter_SLEEP >= 3'd5) begin
                    sec_counter_SLEEP <= 0;
                end else begin
                    sec_counter_SLEEP <= sec_counter_SLEEP + 1;
                end
            end else begin
                sec_counter_SLEEP <= 0;
            end
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            sec_counter_FEED <= 0;
        end else begin
            if (capy_state == CAPY_FEED) begin
                if (sec_counter_FEED >= 3'd5) begin
                    sec_counter_FEED <= 0;
                end else begin
                    sec_counter_FEED <= sec_counter_FEED + 1;
                end
            end else begin
                sec_counter_FEED <= 0;
            end
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            sec_counter_POOPSCENE <= 0;
        end else begin
            if (scene == SCENE_POOPING) begin
                if (sec_counter_POOPSCENE >= 3'd3) begin
                    sec_counter_POOPSCENE <= 0;
                end else begin
                    sec_counter_POOPSCENE <= sec_counter_POOPSCENE + 1;
                end
            end else begin
                sec_counter_POOPSCENE <= 0;
            end
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            sec_counter_GAME_END <= 0;
        end else begin
            if (scene == SCENE_GAMEOVER) begin
                if (sec_counter_GAME_END >= 3'd5) begin
                    sec_counter_GAME_END <= 0;
                end else begin
                    sec_counter_GAME_END <= sec_counter_GAME_END + 1;
                end
            end else begin
                sec_counter_GAME_END <= 0;
            end
        end
    end
    always @(posedge clk_26 or posedge rst) begin
        if (rst) begin
            sec_counter_DEFAULT_SCENE <= 0;
        end else begin
            if (scene == SCENE_DEFAULT) begin
                if (sec_counter_DEFAULT_SCENE >= 4'd10) begin
                    sec_counter_DEFAULT_SCENE <= 0;
                end else begin
                    sec_counter_DEFAULT_SCENE <= sec_counter_DEFAULT_SCENE + 1;
                end
            end else begin
                sec_counter_DEFAULT_SCENE <= 0;
            end
        end
    end
    //capy FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            capy_state <= CAPY_IDLE;
            capy_prev_state <= CAPY_SLEEP;
        end else begin
            capy_state <= next_capy_state;
            if (capy_state == CAPY_WALK || capy_state == CAPY_SLEEP)
                capy_prev_state <= capy_state;
        end
    end
    always @(*) begin
        case (capy_state)
            CAPY_IDLE: begin
                if(touch)begin
                    next_capy_state = CAPY_TOUCH;
                end else if (lowscreen_state == LOWSCREEN_SELECTFOOD && joystick_pressed) begin
                    next_capy_state = CAPY_FEED;
                end else if (sec_counter_IDLE >= 3'd5 && life != 3'b000) begin
                    if (capy_prev_state == CAPY_WALK) begin
                        next_capy_state = CAPY_SLEEP;
                    end else if (capy_prev_state == CAPY_SLEEP) begin
                        next_capy_state = CAPY_WALK;
                    end else begin
                        next_capy_state = CAPY_WALK;
                    end
                end else begin
                    next_capy_state = capy_state;
                end
            end
            CAPY_WALK: begin
                if(touch)begin
                    next_capy_state = CAPY_TOUCH;
                end else if (lowscreen_state == LOWSCREEN_SELECTFOOD && joystick_pressed) begin
                    next_capy_state = CAPY_FEED;
                end else if (sec_counter_WALK >= 3'd5) begin
                    next_capy_state = CAPY_IDLE;
                end else begin
                    next_capy_state = capy_state;
                end
            end
            CAPY_SLEEP : begin
                if(touch)begin
                    next_capy_state = CAPY_TOUCH;
                end else if (lowscreen_state == LOWSCREEN_SELECTFOOD && joystick_pressed) begin
                    next_capy_state = CAPY_FEED;
                end else if (sec_counter_SLEEP >= 3'd5) begin
                    next_capy_state = CAPY_IDLE;
                end else begin
                    next_capy_state = capy_state;
                end
            end
            CAPY_FEED: begin
                if (sec_counter_FEED >= 3'd5) begin
                    next_capy_state = CAPY_IDLE;
                end else begin
                    next_capy_state = capy_state;
                end
            end
            CAPY_TOUCH: begin
                if(!touch)begin
                    next_capy_state = CAPY_IDLE;
                end else begin
                    next_capy_state = capy_state;
                end
            end
        endcase
    end
    // low screen FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lowscreen_state <= LOWSCREEN_INIT;
        end else begin
            lowscreen_state <= next_lowscreen_state;
        end
    end
    always @* begin
        if (scene == SCENE_DEFAULT) begin
            case (lowscreen_state) 
                LOWSCREEN_INIT: begin
                    if (joystick_up) begin
                        next_lowscreen_state = LOWSCREEN_MENU;
                    end else begin
                        next_lowscreen_state = LOWSCREEN_INIT;
                    end
                end
                LOWSCREEN_MENU: begin
                    if (joystick_down) begin
                        next_lowscreen_state = LOWSCREEN_INIT;
                    end else if(joystick_pressed) begin
                        if (event_select[2]) begin
                            next_lowscreen_state = LOWSCREEN_SELECTFOOD;
                        end else if (event_select[1]) begin
                            next_lowscreen_state = LOWSCREEN_CLEAN;
                        end else begin
                            next_lowscreen_state = lowscreen_state;
                        end
                    end else begin
                        next_lowscreen_state = LOWSCREEN_MENU;
                    end
                end
                LOWSCREEN_CLEAN: begin
                    if (water_offset <= 0) begin
                        next_lowscreen_state = LOWSCREEN_INIT;
                    end else begin
                        next_lowscreen_state = lowscreen_state;
                    end
                end
                LOWSCREEN_SELECTFOOD: begin
                    if (joystick_pressed) begin
                        next_lowscreen_state = LOWSCREEN_INIT;
                    end else begin
                        next_lowscreen_state = LOWSCREEN_SELECTFOOD;
                    end
                end
                default: begin
                    next_lowscreen_state = LOWSCREEN_INIT;
                end
            endcase
        end else begin
            next_lowscreen_state = LOWSCREEN_INIT;
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            event_select <= 3'b100;
        end else begin
            if (lowscreen_state == LOWSCREEN_MENU) begin
                if (joystick_right) begin
                    event_select[1:0] <= event_select[2:1];
                    event_select[2] <= event_select[0];
                end else if (joystick_left) begin
                    event_select[2:1] <= event_select[1:0];
                    event_select[0] <= event_select[2];
                end else begin
                    event_select <= event_select;
                end
            end else begin
                event_select <= event_select;
            end
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            food_select <= 3'b100;
        end else begin
            if (lowscreen_state == LOWSCREEN_SELECTFOOD) begin
                if (joystick_right) begin
                    food_select[1:0] <= food_select[2:1];
                    food_select[2] <= food_select[0];
                end else if (joystick_left) begin
                    food_select[2:1] <= food_select[1:0];
                    food_select[0] <= food_select[2];
                end else begin
                    food_select <= food_select;
                end
            end else begin
                food_select <= food_select;
            end
        end
    end
    // scene FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scene <= SCENE_DEFAULT;
        end else begin
            scene <= next_scene;
        end
    end
    always @* begin
        case (scene)
            SCENE_DEFAULT: begin
                if (feed_end) begin
                    next_scene = SCENE_POOPING;
                end else if (lowscreen_state == LOWSCREEN_MENU && event_select[0] && joystick_pressed) begin
                    case (weather)
                        0: next_scene = SCENE_PLAY;
                        1: next_scene = SCENE_HOTSPRING;
                    endcase
                end else begin
                    next_scene = scene;
                end
            end
            SCENE_POOPING: begin
                if (sec_counter_POOPSCENE >= 3) begin
                    next_scene = SCENE_DEFAULT;
                end else begin
                    next_scene = scene;
                end
            end 
            SCENE_PLAY: begin
                if (GAME_ball_offset_y >= 34) begin
                    if (GAME_ball_offset_x + 5 < GAME_capy_offset_x + 3  || GAME_ball_offset_x + 5 > GAME_capy_offset_x + 24) begin
                        next_scene = SCENE_GAMEOVER;
                    end else begin
                        next_scene = scene;
                    end
                end else begin
                    next_scene = scene;
                end
            end
            SCENE_GAMEOVER: begin
                if (sec_counter_GAME_END >= 5) begin
                    next_scene = SCENE_DEFAULT;
                end else begin
                    next_scene = scene;
                end
            end
            SCENE_HOTSPRING: begin
                if (joystick_pressed) begin
                    next_scene = SCENE_DEFAULT;
                end else begin
                    next_scene = scene;
                end
            end
            SCENE_SICK: begin
                if (joystick_pressed) begin
                    next_scene = SCENE_DEFAULT;
                end else begin
                    next_scene = scene;
                end
            end
        endcase
    end
    // GAME animation
    always @(posedge clk_GAME_capy_move or posedge rst) begin
        if (rst) begin
            GAME_capy_offset_x <= 27;
        end else begin
            if (scene == SCENE_PLAY) begin
                if (joystick_right_raw && GAME_capy_offset_x < 53) begin
                    GAME_capy_offset_x <= GAME_capy_offset_x + 1;
                end else if (joystick_left_raw && GAME_capy_offset_x > 0) begin
                    GAME_capy_offset_x <= GAME_capy_offset_x - 1;
                end else begin
                    GAME_capy_offset_x <= GAME_capy_offset_x;
                end
            end else begin
                GAME_capy_offset_x <= 27;
            end
        end
    end
    reg ball_move_right, ball_move_down;
    always @(posedge clk_ball_speed or posedge rst) begin
        if (rst) begin
            ball_move_right <= 1;
            ball_move_down <= 1;
        end else begin
            if (scene == SCENE_PLAY) begin
                if (GAME_ball_offset_x <= 1) begin
                    ball_move_right <= 1;
                end else if (GAME_ball_offset_x >= 70) begin
                    ball_move_right <= 0;
                end else begin
                    ball_move_right <= ball_move_right;
                end

                if (GAME_ball_offset_y <= 1) begin
                    ball_move_down <= 1;
                end else if (GAME_ball_offset_y >= 33) begin
                    ball_move_down <= 0;
                end else begin
                    ball_move_down <= ball_move_down;
                end
            end else begin
                ball_move_right <= 1;
                ball_move_down <= 1;
            end
        end
    end
    always @(posedge clk_ball_speed or posedge rst) begin
        if (rst) begin
            GAME_ball_offset_x <= 1;
            GAME_ball_offset_y <= 1;
        end else begin
            if (scene == SCENE_PLAY) begin
                if (ball_move_right && GAME_ball_offset_x < 71) begin
                    GAME_ball_offset_x <= GAME_ball_offset_x + 1;
                end else if (!ball_move_right && GAME_ball_offset_x > 0) begin
                    GAME_ball_offset_x <= GAME_ball_offset_x - 1;
                end else begin
                    GAME_ball_offset_x <= GAME_ball_offset_x;
                end

                if (ball_move_down && GAME_ball_offset_y < 34) begin
                    GAME_ball_offset_y <= GAME_ball_offset_y + 1;
                end else if (!ball_move_down && GAME_ball_offset_y > 0) begin
                    GAME_ball_offset_y <= GAME_ball_offset_y - 1;
                end else begin
                    GAME_ball_offset_y <= GAME_ball_offset_y;
                end 

            end else begin
                GAME_ball_offset_x <= 1;
                GAME_ball_offset_y <= 1;
            end
        end
    end
    // CLEAN animation
    always @(posedge clk_water or posedge rst) begin
        if (rst) begin
            water_offset <= 81;
        end else begin
            if (lowscreen_state == LOWSCREEN_CLEAN) begin
                if (water_offset > 0) begin
                    water_offset <= water_offset - 1;    
                end else begin
                    water_offset <= water_offset;
                end
            end else begin
                water_offset <= 81;
            end
        end
    end
    // WALK animation control
    always @(posedge clk_WALK or posedge rst) begin
        if (rst) begin
            capy_offset_x <= 8'd20;
            Direction <= WALK_LEFT;
        end else begin
            if (capy_state == CAPY_WALK) begin
                if (Direction == WALK_RIGHT) begin
                    if (capy_offset_x < 8'd40) begin
                        capy_offset_x <= capy_offset_x + 1;
                    end else begin
                        Direction <= WALK_LEFT;
                    end
                end else begin
                    if (capy_offset_x > 8'd0) begin
                        capy_offset_x <= capy_offset_x - 1;
                    end else begin
                        Direction <= WALK_RIGHT;
                    end
                end
            end else begin
                capy_offset_x <= capy_offset_x;
                Direction <= Direction;
            end
        end
    end
    reg WALK_frame;
    always @(posedge clk_WALK or posedge rst) begin
        if (rst) begin
            WALK_frame <= 1'b0;
        end else begin
            WALK_frame <= ~WALK_frame;
        end
    end
    reg [1:0] SLEEP_frame;
    always @(posedge clk_animation or posedge rst) begin
        if (rst) begin
            SLEEP_frame <= 1'b0;
        end else begin
            if (SLEEP_frame >= 3) begin
                SLEEP_frame <= 0;
            end else begin
                SLEEP_frame <= SLEEP_frame + 1;
            end
        end
    end
    reg [1:0] TOUCH_frame;
    always@(posedge clk_animation or posedge rst)begin
        if(rst)begin
            TOUCH_frame <= 1'b0;
        end else begin
            if(TOUCH_frame >= 1)begin
                TOUCH_frame <= 0;
            end else begin
                TOUCH_frame <= TOUCH_frame +1;
            end
        end
    end
    reg [2:0] FEED_dango_frame;
    always @(posedge clk_animation or posedge rst) begin
        if (rst) begin
            FEED_dango_frame <= 1'b0;
        end else begin
            if (FEED_dango_frame >= 3) begin
                FEED_dango_frame <= 0;
            end else begin
                FEED_dango_frame <= FEED_dango_frame + 1;
            end
        end
    end
	reg [2:0] FEED_chip_frame;
    always @(posedge clk_animation or posedge rst) begin
        if (rst) begin
            FEED_chip_frame <= 1'b0;
        end else begin
            if (FEED_chip_frame >= 4) begin
                FEED_chip_frame <= 0;
            end else begin
                FEED_chip_frame <= FEED_chip_frame + 1;
            end
        end
    end
    reg [2:0] FEED_tea_frame;
    always @(posedge clk_animation or posedge rst) begin
        if (rst) begin
            FEED_tea_frame <= 1'b0;
        end else begin
            if (FEED_tea_frame >= 3) begin
                FEED_tea_frame <= 0;
            end else begin
                FEED_tea_frame <= FEED_tea_frame + 1;
            end
        end
    end
    // reg [1:0] water_frame;
    // always @(posedge clk_animation or posedge rst) begin
    //     if (rst) begin
    //         water_frame <= 1'b0;
    //     end else begin
    //         if (water_frame >= 2) begin
    //             water_frame <= 0;
    //         end else begin
    //             water_frame <= water_frame + 1;
    //         end
    //     end
    // end
    reg [2:0] spin_frame;
    always @(posedge clk_23 or posedge rst) begin
        if (rst) begin
            spin_frame <= 0;
        end else begin
            if (spin_frame >= 4) begin
                spin_frame <= 0;
            end else begin
                spin_frame <= spin_frame + 1;
            end
        end
    end
    reg [1:0] GAME_END_frame;
    always @(posedge clk_animation or posedge rst) begin
        if (rst) begin
            GAME_END_frame <= 0;
        end else begin
            if (GAME_END_frame >= 3) begin
                GAME_END_frame <= 0;
            end else begin
                GAME_END_frame <= GAME_END_frame + 1;
            end
        end
    end
    reg hotspring_frame;
    always @(posedge clk_animation or posedge rst) begin
        if (rst) begin
            hotspring_frame <= 0;
        end else begin
            hotspring_frame <= ~hotspring_frame;
        end
    end
	// Instantiate block memory for image storage
	wire [11:0] pixel_data_capy_IDLE;
    wire [11:0] pixel_data_capy_WALK_0;
    wire [11:0] pixel_data_capy_WALK_1;
    wire [11:0] pixel_data_capy_WALK_2;
    wire [11:0] pixel_data_capy_SLEEP_0;
    wire [11:0] pixel_data_capy_SLEEP_1;
    wire [11:0] pixel_data_capy_SLEEP_2;
    wire [11:0] pixel_data_capy_TOUCH_0;
    wire [11:0] pixel_data_capy_TOUCH_1;
    wire [11:0] pixel_data_heart;
    wire [11:0] pixel_data_chicken;
    wire [11:0] pixel_data_dango;
    wire [11:0] pixel_data_dango_select;
    wire [11:0] pixel_data_chip;
    wire [11:0] pixel_data_chip_select;
    wire [11:0] pixel_data_tea;
    wire [11:0] pixel_data_tea_select;
    wire [11:0] pixel_data_food;
    wire [11:0] pixel_data_food_select;
    wire [11:0] pixel_data_clean;
    wire [11:0] pixel_data_clean_select;
    wire [11:0] pixel_data_play;
    wire [11:0] pixel_data_play_select;
    wire [11:0] pixel_data_spring;
    wire [11:0] pixel_data_spring_select;
    wire [11:0] pixel_data_capy_FEED_dango_0;
    wire [11:0] pixel_data_capy_FEED_dango_1;
    wire [11:0] pixel_data_capy_FEED_dango_2;
    wire [11:0] pixel_data_capy_FEED_dango_3;
    wire [11:0] pixel_data_capy_FEED_chip_0;
    wire [11:0] pixel_data_capy_FEED_chip_1;
    wire [11:0] pixel_data_capy_FEED_chip_2;
    wire [11:0] pixel_data_capy_FEED_chip_3;
    wire [11:0] pixel_data_capy_FEED_chip_4;
    wire [11:0] pixel_data_capy_FEED_tea_0;
    wire [11:0] pixel_data_capy_FEED_tea_1;
    wire [11:0] pixel_data_capy_FEED_tea_2;
    wire [11:0] pixel_data_capy_FEED_tea_3;
    wire [11:0] pixel_data_poopground;
    wire [11:0] pixel_data_poopingscene;
    wire [11:0] pixel_data_water;
    wire [11:0] pixel_data_spin_0;
    wire [11:0] pixel_data_spin_1;
    wire [11:0] pixel_data_spin_2;
    wire [11:0] pixel_data_spin_3;
    wire [11:0] pixel_data_spin_4;
    wire [11:0] pixel_data_ball;
    wire [11:0] pixel_data_GAMEEND_0;
    wire [11:0] pixel_data_GAMEEND_1;
    wire [11:0] pixel_data_GAMEEND_2;
    wire [11:0] pixel_data_GAMEEND_3;
    wire [11:0] pixel_data_sun;
    wire [11:0] pixel_data_snow;
    wire [11:0] pixel_data_hotspring_0;
    wire [11:0] pixel_data_hotspring_1;
    wire [11:0] pixel_data_icebar;
    wire [11:0] pixel_data_icebar_selected;
    wire [11:0] pixel_data_capy_eat_ice_0;
    wire [11:0] pixel_data_capy_eat_ice_1;
    wire [11:0] pixel_data_capy_eat_ice_2;
    wire [11:0] pixel_data_capy_eat_ice_3;
	blk_mem_gen_0 capy_IDLE_image(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_IDLE)
    );
    blk_mem_gen_1 capy_WALK_image_0(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_WALK_0)
    );
    blk_mem_gen_2 capy_WALK_image_1(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_WALK_1)
    );
    blk_mem_gen_SLEEP0 capy_SLEEP_image_0(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_SLEEP_0)
    );
    blk_mem_gen_SLEEP1 capy_SLEEP_image_1(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_SLEEP_1)
    );
    blk_mem_gen_SLEEP2 capy_SLEEP_image_2(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_SLEEP_2)
    );
    blk_mem_gen_TOUCH0 capy_TOUCH_image_0(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_TOUCH_0)
    );
    blk_mem_gen_TOUCH1 capy_TOUCH_image_1(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_TOUCH_1)
    );


    blk_mem_gen_FEED_dango0 capy_FEED_dango_image_0(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_dango_0)
    );
    blk_mem_gen_FEED_dango1 capy_FEED_dango_image_1(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_dango_1)
    );
    blk_mem_gen_FEED_dango2 capy_FEED_dango_image_2(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_dango_2)
    );

    blk_mem_gen_FEED_dango3 capy_FEED_dango_image_3(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_dango_3)
    );

    blk_mem_gen_FEED_chip0 capy_FEED_chip_image_0(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_chip_0)
    );
    
    blk_mem_gen_FEED_chip1 capy_FEED_chip_image_1(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_chip_1)
    );
    blk_mem_gen_FEED_chip2 capy_FEED_chip_image_2(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_chip_2)
    );

    blk_mem_gen_FEED_chip3 capy_FEED_chip_image_3(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_chip_3)
    );

    blk_mem_gen_FEED_chip4 capy_FEED_chip_image_4(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_chip_4)
    );

    blk_mem_gen_FEED_tea0 capy_FEED_tea_image_0(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_tea_0)
    );
    blk_mem_gen_FEED_tea1 capy_FEED_tea_image_1(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_tea_1)
    );
    blk_mem_gen_FEED_tea2 capy_FEED_tea_image_2(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_tea_2)
    );
    blk_mem_gen_FEED_tea3 capy_FEED_tea_image_3(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_FEED_tea_3)
    );
    
    blk_mem_gen_heart heart_img(
        .clka(clk),
        .wea(1'b0),
        .addra(heart_addr),
        .dina(12'd0),
        .douta(pixel_data_heart)
    );
    blk_mem_gen_chicken chicken_img(
        .clka(clk),
        .wea(1'b0),
        .addra(chicken_addr),
        .dina(12'd0),
        .douta(pixel_data_chicken)
    );
    blk_mem_gen_dango dango_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_dango)
    );
    blk_mem_gen_dango_select dango_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_dango_select)
    );
    blk_mem_gen_chip chip_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_chip)
    );
    blk_mem_gen_chip_select chip_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_chip_select)
    );
    blk_mem_gen_tea tea_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_tea)
    );
    blk_mem_gen_tea_select tea_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_tea_select)
    );
    blk_mem_gen_food food_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_food)
    );
    blk_mem_gen_food_select food_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_food_select)
    );
    blk_mem_gen_clean clean_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_clean)
    );
    blk_mem_gen_clean_select clean_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_clean_select)
    );
    blk_mem_gen_play play_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_play)
    );
    blk_mem_gen_play_select play_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_play_select)
    );
    blk_mem_gen_spring spring_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_spring)
    );
    blk_mem_gen_spring_select spring_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_spring_select)
    );
    blk_mem_gen_icebar icebar_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_icebar)
    );
    blk_mem_gen_icebar_select icebar_select_img(
        .clka(clk),
        .wea(1'b0),
        .addra(menu_addr),
        .dina(12'd0),
        .douta(pixel_data_icebar_selected)
    );
    blk_mem_gen_poop poop_img(
        .clka(clk),
        .wea(1'b0),
        .addra(poop_addr),
        .dina(12'd0),
        .douta(pixel_data_poopground)
    );
    blk_mem_gen_pooping_scene pooping_scnene_img(
        .clka(clk),
        .wea(1'b0),
        .addra(pooping_scene_addr),
        .dina(12'd0),
        .douta(pixel_data_poopingscene)
    );
    blk_mem_gen_water water_img(
        .clka(clk),
        .wea(1'b0),
        .addra(water_addr),
        .dina(12'd0),
        .douta(pixel_data_water)
    );
    // blk_mem_gen_water1 water_img_1(
    //     .clka(clk),
    //     .wea(1'b0),
    //     .addra(water_addr),
    //     .dina(12'd0),
    //     .douta(pixel_data_water_1)
    // );
    // blk_mem_gen_water2 water_img_2(
    //     .clka(clk),
    //     .wea(1'b0),
    //     .addra(water_addr),
    //     .dina(12'd0),
    //     .douta(pixel_data_water_2)
    // );
    blk_mem_gen_spin0 spin_img_0(
        .clka(clk),
        .wea(1'b0),
        .addra(spin_addr),
        .dina(12'd0),
        .douta(pixel_data_spin_0)
    );
    blk_mem_gen_spin1 spin_img_1(
        .clka(clk),
        .wea(1'b0),
        .addra(spin_addr),
        .dina(12'd0),
        .douta(pixel_data_spin_1)
    );
    blk_mem_gen_spin2 spin_img_2(
        .clka(clk),
        .wea(1'b0),
        .addra(spin_addr),
        .dina(12'd0),
        .douta(pixel_data_spin_2)
    );
    blk_mem_gen_spin3 spin_img_3(
        .clka(clk),
        .wea(1'b0),
        .addra(spin_addr),
        .dina(12'd0),
        .douta(pixel_data_spin_3)
    );
    blk_mem_gen_spin4 spin_img_4(
        .clka(clk),
        .wea(1'b0),
        .addra(spin_addr),
        .dina(12'd0),
        .douta(pixel_data_spin_4)
    );
    blk_mem_gen_ball ball_img(
        .clka(clk),
        .wea(1'b0),
        .addra(ball_addr),
        .dina(12'd0),
        .douta(pixel_data_ball)
    );
    blk_mem_gen_GAMEEND0 GAMEEND_img_0(
        .clka(clk),
        .wea(1'b0),
        .addra(GAMEEND_scene_addr),
        .dina(12'd0),
        .douta(pixel_data_GAMEEND_0)
    );
    blk_mem_gen_GAMEEND1 GAMEEND_img_1(
        .clka(clk),
        .wea(1'b0),
        .addra(GAMEEND_scene_addr),
        .dina(12'd0),
        .douta(pixel_data_GAMEEND_1)
    );
    blk_mem_gen_GAMEEND2 GAMEEND_img_2(
        .clka(clk),
        .wea(1'b0),
        .addra(GAMEEND_scene_addr),
        .dina(12'd0),
        .douta(pixel_data_GAMEEND_2)
    );
    blk_mem_gen_GAMEEND3 GAMEEND_img_3(
        .clka(clk),
        .wea(1'b0),
        .addra(GAMEEND_scene_addr),
        .dina(12'd0),
        .douta(pixel_data_GAMEEND_3)
    );
    blk_mem_gen_sun sun_img(
        .clka(clk),
        .wea(1'b0),
        .addra(weather_addr),
        .dina(12'd0),
        .douta(pixel_data_sun)
    );
    blk_mem_gen_snow snow_img(
        .clka(clk),
        .wea(1'b0),
        .addra(weather_addr),
        .dina(12'd0),
        .douta(pixel_data_snow)
    );
    blk_mem_gen_hotspring0 hotspring_img_0(
        .clka(clk),
        .wea(1'b0),
        .addra(hotspring_scene_addr),
        .dina(12'd0),
        .douta(pixel_data_hotspring_0)
    );
    blk_mem_gen_hotspring1 hotspring_img_1(
        .clka(clk),
        .wea(1'b0),
        .addra(hotspring_scene_addr),
        .dina(12'd0),
        .douta(pixel_data_hotspring_1)
    );
    blk_mem_gen_capy_icebar0 capy_eat_ice_img_0(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_eat_ice_0)
    );
    blk_mem_gen_capy_icebar1 capy_eat_ice_img_1(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_eat_ice_1)
    );
    blk_mem_gen_capy_icebar2 capy_eat_ice_img_2(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_eat_ice_2)
    );
    blk_mem_gen_capy_icebar3 capy_eat_ice_img_3(
        .clka(clk),
        .wea(1'b0),
        .addra(capy_img_addr),
        .dina(12'd0),
        .douta(pixel_data_capy_eat_ice_3)
    );
    // Convert 12-bit pixel data (RGB444) to 16-bit (RGB565), or black if out of bounds
	reg [11:0] pixel_data;
    always @* begin
        case (scene)
            SCENE_DEFAULT: begin
                if (y <= 1) 
                    if (x >= 33 && x < 48) begin
                        case(weather) 
                            0: pixel_data = pixel_data_sun;
                            1: pixel_data = pixel_data_snow;
                        endcase
                    end else begin
                        pixel_data = 12'hfff;
                    end
                else if (y >= 1 && y < 11) begin
                    if (x < 10) begin
                        if (life[2])
                            pixel_data = pixel_data_heart;
                        else 
                            pixel_data = 12'hfff;
                    end else if (x >= 10 && x < 20) begin
                        if (life[1])
                        pixel_data = pixel_data_heart;
                    else 
                        pixel_data = 12'hfff;
                    end else if (x >= 20 && x < 30) begin
                        if (life[0])
                            pixel_data = pixel_data_heart;
                        else 
                            pixel_data = 12'hfff;
                    end else if (x >= 51 && x < 61) begin
                        if (chicken[2]) 
                            pixel_data = pixel_data_chicken;
                        else 
                            pixel_data = 12'hfff;
                    end else if (x >= 61 && x < 71) begin
                        if (chicken[1]) 
                            pixel_data = pixel_data_chicken;
                        else 
                            pixel_data = 12'hfff;
                    end else if (x >= 71 && x < 81) begin
                        if (chicken[0]) 
                            pixel_data = pixel_data_chicken;
                        else 
                            pixel_data = 12'hfff;
                    end else if (x >= 33 && x < 48) begin
                        case(weather) 
                            0: pixel_data = pixel_data_sun;
                            1: pixel_data = pixel_data_snow;
                        endcase
                    end else begin
                        pixel_data = 12'hFFF; 
                    end
                end else if (y >= 11 && y < capy_offset_y) begin
                    if (x >= 33 && x < 48) begin
                        case(weather) 
                            0: pixel_data = pixel_data_sun;
                            1: pixel_data = pixel_data_snow;
                        endcase
                    end else begin
                        pixel_data = 12'hfff;
                    end
                end else if (x >=capy_offset_x && x < (capy_offset_x + 8'd41) && y >= capy_offset_y && y < (capy_offset_y + 8'd33)) begin
                    case (capy_state)
                        CAPY_IDLE: begin
                            pixel_data = pixel_data_capy_IDLE;
                        end
                        CAPY_WALK: begin
                            if (WALK_frame == 1'b0) begin
                                pixel_data = pixel_data_capy_WALK_0;
                            end else begin
                                pixel_data = pixel_data_capy_WALK_1;
                            end
                        end
                        CAPY_SLEEP: begin
                            case (SLEEP_frame)
                                0: begin
                                pixel_data = pixel_data_capy_SLEEP_0; 
                                end
                                1: begin
                                    pixel_data = pixel_data_capy_SLEEP_1; 
                                end
                                2: begin
                                    pixel_data = pixel_data_capy_SLEEP_2; 
                                end
                                3: begin
                                    pixel_data = pixel_data_capy_SLEEP_0; 
                                end
                            endcase
                        end
                        CAPY_TOUCH:begin
                            case(TOUCH_frame)
                                0:begin
                                    pixel_data = pixel_data_capy_TOUCH_0;
                                end
                                1:begin
                                    pixel_data = pixel_data_capy_TOUCH_1;
                                end
                            endcase
                        end
                        CAPY_FEED: begin
                            case (food_select) 
                                3'b100: begin // dango
                                    case (FEED_dango_frame)
                                        0: pixel_data = pixel_data_capy_FEED_dango_0;
                                        1: pixel_data = pixel_data_capy_FEED_dango_1;
                                        2: pixel_data = pixel_data_capy_FEED_dango_2;
                                        3: pixel_data = pixel_data_capy_FEED_dango_3;
                                        default:pixel_data = pixel_data_capy_FEED_dango_0;
                                    endcase
                                end
                                3'b010: begin // chip
                                    case (FEED_chip_frame)
                                        0: pixel_data = pixel_data_capy_FEED_chip_0;
                                        1: pixel_data = pixel_data_capy_FEED_chip_1;
                                        2: pixel_data = pixel_data_capy_FEED_chip_2;
                                        3: pixel_data = pixel_data_capy_FEED_chip_3;
                                        4: pixel_data = pixel_data_capy_FEED_chip_4;
                                    endcase
                                end
                                3'b001: begin // tea or ice
                                    case (weather_enter_feed)
                                        0: begin
                                            case (FEED_tea_frame)
                                                0: pixel_data = pixel_data_capy_eat_ice_0;
                                                1: pixel_data = pixel_data_capy_eat_ice_1;
                                                2: pixel_data = pixel_data_capy_eat_ice_2;
                                                3: pixel_data = pixel_data_capy_eat_ice_3;
                                            endcase
                                        end
                                        1: begin
                                            case (FEED_tea_frame)
                                                0: pixel_data = pixel_data_capy_FEED_tea_0;
                                                1: pixel_data = pixel_data_capy_FEED_tea_1;
                                                2: pixel_data = pixel_data_capy_FEED_tea_2;
                                                3: pixel_data = pixel_data_capy_FEED_tea_3;
                                            endcase
                                        end
                                    endcase
                                end 
                            endcase

                        end
                    endcase
                end else if (y >= (capy_offset_y + 8'd33) && y < (capy_offset_y + 8'd33) + 18) begin // low screen
                    case (lowscreen_state) 
                        LOWSCREEN_INIT: begin // display poop
                            if (x >= 15 && x < 25 && y >= 54 && y < 64 && poop_count >= 1) begin
                                pixel_data = pixel_data_poopground;
                            end else if (x >= 32 && x < 42 && y >= 48 && y < 58 && poop_count >= 2) begin
                                pixel_data = pixel_data_poopground;
                            end else if (x >= 65 && x < 75 && y >= 51 && y < 61 && poop_count >= 3) begin
                                pixel_data = pixel_data_poopground;
                            end else begin
                                pixel_data = 12'hfff;
                            end
                        end 
                        LOWSCREEN_MENU: begin
                            if (x < 27) begin
                                pixel_data = (event_select[2]) ? pixel_data_food_select : pixel_data_food;
                            end else if (x >= 27 && x < 54) begin
                                pixel_data = (event_select[1]) ? pixel_data_clean_select : pixel_data_clean;
                            end else if (x >= 54 && x < 81) begin
                                case (weather)
                                    0: pixel_data = (event_select[0]) ? pixel_data_play_select : pixel_data_play;
                                    1: pixel_data = (event_select[0]) ? pixel_data_spring_select : pixel_data_spring;
                                endcase
                            end else begin
                                pixel_data = 12'hFFF; 
                            end
                        end
                        LOWSCREEN_CLEAN: begin
                            if (x < water_offset) begin // display poop
                                if (x >= 15 && x < 25 && y >= 54 && y < 64 && poop_count >= 1) begin
                                    pixel_data = pixel_data_poopground;
                                end else if (x >= 32 && x < 42 && y >= 48 && y < 58 && poop_count >= 2) begin
                                    pixel_data = pixel_data_poopground;
                                end else if (x >= 65 && x < 75 && y >= 51 && y < 61 && poop_count >= 3) begin
                                    pixel_data = pixel_data_poopground;
                                end else begin
                                    pixel_data = 12'hfff;
                                end
                            end else begin
                                pixel_data = pixel_data_water;
                            end
                        end
                        LOWSCREEN_SELECTFOOD: begin
                            if (x < 27) begin
                                pixel_data = (food_select[2]) ? pixel_data_dango_select : pixel_data_dango;
                            end else if (x >= 27 && x < 54) begin
                                pixel_data = (food_select[1]) ? pixel_data_chip_select : pixel_data_chip;
                            end else if (x >= 54 && x < 81) begin
                                case (weather) 
                                    0: pixel_data = (food_select[0]) ? pixel_data_icebar_selected : pixel_data_icebar;
                                    1: pixel_data = (food_select[0]) ? pixel_data_tea_select : pixel_data_tea;
                                endcase
                            end else begin
                                pixel_data = 12'hFFF; 
                            end
                        end
                    endcase
                end else begin
                    pixel_data = 12'hFFF; 
                end
            end
            SCENE_GAMEOVER: begin 
                case(GAME_END_frame)
                    0: pixel_data = pixel_data_GAMEEND_0;
                    1: pixel_data = pixel_data_GAMEEND_1;
                    2: pixel_data = pixel_data_GAMEEND_2;
                    3: pixel_data = pixel_data_GAMEEND_3;
                endcase
            end
            SCENE_PLAY: begin
                if (y >= GAME_capy_offset_y) begin
                    if (x >= GAME_capy_offset_x && x < GAME_capy_offset_x + 27) begin
                        case (spin_frame) 
                            0: pixel_data = pixel_data_spin_0; 
                            1: pixel_data = pixel_data_spin_1; 
                            2: pixel_data = pixel_data_spin_2; 
                            3: pixel_data = pixel_data_spin_3; 
                            4: pixel_data = pixel_data_spin_4; 
                        endcase
                    end else begin
                        pixel_data = 12'hfff;
                    end
                end else begin
                    if (x >= GAME_ball_offset_x && x < GAME_ball_offset_x + 10 && y >= GAME_ball_offset_y && y < GAME_ball_offset_y + 10) begin
                        pixel_data = pixel_data_ball;
                    end else begin
                        pixel_data = 12'hfff;
                    end
                end
            end
            SCENE_POOPING: begin
                if (x >= 13 && x < 67 && y >= 11 && y < 55) begin
                    pixel_data = pixel_data_poopingscene;
                end else begin
                    pixel_data = 12'hfff; 
                end
            end
            SCENE_SICK: begin
                pixel_data = 12'hfff;
            end
            SCENE_HOTSPRING: begin
                case(hotspring_frame)
                    0: pixel_data = pixel_data_hotspring_0;
                    1: pixel_data = pixel_data_hotspring_1;
                endcase
            end
        endcase
        
    end
	assign ram_lcd_data ={pixel_data[11:8],pixel_data[11],pixel_data[7:4],pixel_data[7:6],pixel_data[3:0],pixel_data[3]};
    always @* begin
        case(lowscreen_state)
            LOWSCREEN_INIT: begin
                LED[15:12] = 4'b1000;
            end
            LOWSCREEN_MENU: begin
                LED[15:12] = 4'b0100;
            end
            LOWSCREEN_SELECTFOOD: begin
                LED[15:12] = 4'b0010;
            end
            LOWSCREEN_CLEAN: begin
                LED[15:12] = 4'b0001;
            end
        endcase
        LED[11:9] = event_select;
        LED[8:6] = food_select;
    end
    
    always @(*) begin
        if (distance > 20'd9999) begin
            distance_display = 16'b1001_1001_1001_1001;
        end else begin
            distance_display[3:0] = distance % 10;
            distance_display[7:4] = (distance / 10) % 10;
            distance_display[11:8] = (distance / 100) % 10;
            distance_display[15:12] = (distance / 1000) % 10;
        end
    end
    SevenSegment seven_segment_display(
        .clk(clk),
        .rst(rst),
        .nums(distance_display),
        .display(DISPLAY),
        .digit(DIGIT)
    );
    //assign ram_lcd_data = 16'hF800;  // Red (RGB565 format)
    
endmodule

module SevenSegment(
	output reg [6:0] display,
	output reg [3:0] digit,
	input wire [15:0] nums,
	input wire rst,
	input wire clk
    );
    
    reg [15:0] clk_divider;
    reg [3:0] display_num;
    
    always @ (posedge clk, posedge rst) begin
    	if (rst) begin
    		clk_divider <= 15'b0;
    	end else begin
    		clk_divider <= clk_divider + 15'b1;
    	end
    end
    
    always @ (posedge clk_divider[15], posedge rst) begin
    	if (rst) begin
    		display_num <= 4'b0000;
    		digit <= 4'b1111;
    	end else begin
    		case (digit)
    			4'b1110 : begin
    					display_num <= nums[7:4];
    					digit <= 4'b1101;
    				end
    			4'b1101 : begin
						display_num <= nums[11:8];
						digit <= 4'b1011;
					end
    			4'b1011 : begin
						display_num <= nums[15:12];
						digit <= 4'b0111;
					end
    			4'b0111 : begin
						display_num <= nums[3:0];
						digit <= 4'b1110;
					end
    			default : begin
						display_num <= nums[3:0];
						digit <= 4'b1110;
					end				
    		endcase
    	end
    end
    
    always @ (*) begin
    	case (display_num)
    		0 : display = 7'b1000000;	//0000
			1 : display = 7'b1111001;   //0001                                                
			2 : display = 7'b0100100;   //0010                                                
			3 : display = 7'b0110000;   //0011                                             
			4 : display = 7'b0011001;   //0100                                               
			5 : display = 7'b0010010;   //0101                                               
			6 : display = 7'b0000010;   //0110
			7 : display = 7'b1111000;   //0111
			8 : display = 7'b0000000;   //1000
			9 : display = 7'b0010000;	//1001
			default : display = 7'b1111111;
    	endcase
    end
    
endmodule