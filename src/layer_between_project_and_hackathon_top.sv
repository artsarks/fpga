`include "swap_bits.svh"

module layer_between_project_and_hackathon_top
(
    input              clock,
    input              reset,

    output             tm1638_clk,
    output             tm1638_stb,

    input              tm1638_dio_in,
    output             tm1638_dio_out,
    output             tm1638_dio_out_en,

    output logic       vga_hsync,
    output logic       vga_vsync,

    output logic [1:0] vga_red,
    output logic [1:0] vga_green,
    output logic [1:0] vga_blue,

    output             sticky_failure
);

    //------------------------------------------------------------------------

    localparam clk_mhz = 25;

    // TODO: Think how to use this signal for self-diagnostics
    assign sticky_failure = 1'b0;

    //------------------------------------------------------------------------

    wire slow_clock = clock;

    wire [7:0] key;
    wire [7:0] led;

    // A dynamic seven-segment display

    wire [7:0] abcdefgh;
    wire [7:0] digit;

    // LCD screen interface

    wire [8:0] x;
    wire [8:0] y;

    wire [4:0] red;
    wire [5:0] green;
    wire [4:0] blue;

    //------------------------------------------------------------------------

    hackathon_top i_hackathon_top (.*);

    //------------------------------------------------------------------------

    wire [7:0]  hgfedcba;
    `SWAP_BITS (hgfedcba, abcdefgh);

    tm1638_board_controller
    # (
        .clk_mhz          ( clk_mhz           ),
        .w_digit          ( 8                 ),
        .w_seg            ( 8                 )
    )
    i_tm1638
    (
        .clk              ( clock             ),
        .rst              ( reset             ),
        .hgfedcba         ,
        .digit            ,
        .ledr             ( led               ),
        .keys             ( key               ),

        .sio_clk          ( tm1638_clk        ),
        .sio_stb          ( tm1638_stb        ),

        .sio_data_in      ( tm1638_dio_in     ),
        .sio_data_out     ( tm1638_dio_out    ),
        .sio_data_out_en  ( tm1638_dio_out_en )
    );

    //------------------------------------------------------------------------

    wire hsync, vsync, display_on;

    wire [9:0] hpos; assign x = hpos [$left (x):0];
    wire [9:0] vpos; assign y = vpos [$left (y):0];

    wire pixel_clk;  // Unused because main clock is 25 MHz

    vga
    # (
        .CLK_MHZ     ( clk_mhz ),
        .PIXEL_MHZ   ( clk_mhz )
    )
    i_vga
    (
        .clk         ( clock   ),
        .rst         ( reset   ),

        .hsync       ,
        .vsync       ,

        .display_on  ,

        .hpos        ,
        .vpos        ,

        .pixel_clk
    );

    //------------------------------------------------------------------------

    always_ff @ (posedge clock)
        if (reset)
        begin
            vga_hsync <= 1'b0;
            vga_vsync <= 1'b0;
        end
        else
        begin
            vga_hsync <= hsync;
            vga_vsync <= vsync;
        end

    //------------------------------------------------------------------------

    `define REDUCE_COLOR_TO_2_BITS(c)  \
        (display_on ? { c [$left (c)], | c [$left (c) - 1:0] } : '0)

    always_ff @ (posedge clock)
    begin
        vga_red   <= `REDUCE_COLOR_TO_2_BITS ( red   );
        vga_green <= `REDUCE_COLOR_TO_2_BITS ( green );
        vga_blue  <= `REDUCE_COLOR_TO_2_BITS ( blue  );
    end

    `undef REDUCE_COLOR_TO_2_BITS

endmodule
