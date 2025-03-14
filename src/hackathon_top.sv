module hackathon_top
(
    input  logic       clock,
    input  logic       slow_clock,
    input  logic       reset,

    input  logic [7:0] key,
    output logic [7:0] led,

    output logic [7:0] abcdefgh,
    output logic [7:0] digit,

    input  logic [8:0] x,
    input  logic [8:0] y,

    output logic [4:0] red,
    output logic [5:0] green,
    output logic [4:0] blue,

    inout  logic [2:0] gpio
);

    // Screen, object and color constants
    localparam screen_width  = 480,
               screen_height = 272,
               wx            = 30,
               wy            = 30,
               max_red       = 31,
               max_green     = 63,
               max_blue      = 31;

    // Pulse generator, 50 times a second
    logic enable;
    strobe_gen # (.clk_mhz (27), .strobe_hz (100))
    i_strobe_gen (clock, reset, enable);

    // FSM state transition logic
    logic [2:0] state, new_state;
    logic out_of_screen, collision, launch, timeout;

    // Object coordinates
    logic [8:0] x_blue[5:0], y_blue[5:0];
    logic [8:0] x_red, y_red;
    logic [8:0] x_green[8:0], y_green[8:0];  // New 9 green objects (8:0 index)
    logic direction_blue[5:0], direction_green[8:0];  // Directions for green

    // Initialize object positions
    always_ff @ (posedge clock)
    begin
        if (reset)
        begin
            for (int i = 0; i < 6; i++)
            begin
                x_blue[i] <= i * 70 + 5;
                y_blue[i] <= screen_height / 3 * (i % 2) + wy;
                x_green[i] <= x_blue[i]; // Initialize green objects at the same position as blue
                y_green[i] <= y_blue[i];
                direction_blue[i] <= 1; // Move right
                direction_green[i] <= 1; // Move down (perpendicular to blue)
            end

            // Initialize remaining 3 green objects
            for (int i = 6; i < 9; i++)
            begin
                x_green[i] <= i * 70 + 5;
                y_green[i] <= screen_height / 3 * (i % 2) + wy;
                direction_green[i] <= 1; // Move down initially
            end

            x_red <= screen_width / 2;
            y_red <= screen_height / 2;
        end
        else if (enable)
        begin
            for (int i = 0; i < 6; i++)
            begin
                // Blue objects move horizontally
                if (direction_blue[i] == 1)
                begin
                    if (x_blue[i] < screen_width - wx - 5)
                        x_blue[i] <= x_blue[i] + 1;
                    else
                        direction_blue[i] <= 0; // Change direction to left
                end
                else
                begin
                    if (x_blue[i] > 5)
                        x_blue[i] <= x_blue[i] - 1;
                    else
                        direction_blue[i] <= 1; // Change direction to right
                end

                // Green objects move vertically (perpendicular to blue objects)
                if (direction_green[i] == 1)
                begin
                    if (y_green[i] < screen_height - wy - 5)
                        y_green[i] <= y_green[i] + 1; // Move down
                    else
                        direction_green[i] <= 0; // Change direction to up
                end
                else
                begin
                    if (y_green[i] > 5)
                        y_green[i] <= y_green[i] - 1; // Move up
                    else
                        direction_green[i] <= 1; // Change direction to down
                end
            end

            // Handle movement for remaining 3 green objects
            for (int i = 6; i < 9; i++)
            begin
                if (direction_green[i] == 1)
                begin
                    if (y_green[i] < screen_height - wy - 5)
                        y_green[i] <= y_green[i] + 1; // Move down
                    else
                        direction_green[i] <= 0; // Change direction to up
                end
                else
                begin
                    if (y_green[i] > 5)
                        y_green[i] <= y_green[i] - 1; // Move up
                    else
                        direction_green[i] <= 1; // Change direction to down
                end
            end

            // Red object movement controlled by player
            if (key[0] && x_red < screen_width - wx - 5) x_red <= x_red + 1;
            if (key[1] && x_red > 5) x_red <= x_red - 1;
            if (key[2] && y_red > 5) y_red <= y_red - 1;
            if (key[3] && y_red < screen_height - wy - 5) y_red <= y_red + 1;

            // Check for collisions with green and blue objects
for (int i = 0; i < 9; i++)
begin
    if (x_red < x_green[i] + wx && x_red + wx > x_green[i] &&
        y_red < y_green[i] + wy && y_red + wy > y_green[i])
    begin
        // Reset red object position if collision occurs
        x_red <= screen_width / 2;
        y_red <= screen_height / 2;
    end
end

for (int i = 0; i < 6; i++)
begin
    if (x_red < x_blue[i] + wx && x_red + wx > x_blue[i] &&
        y_red < y_blue[i] + wy && y_red + wy > y_blue[i])
    begin
        // Reset red object position if collision occurs
        x_red <= screen_width / 2;
        y_red <= screen_height / 2;
    end
end
        end
    end

    // Determine pixel color
    always_comb
    begin
        red   = 0;
        green = 0; 
        blue  = 0;

        // White border (5 pixels thick)
        if (x < 5 || x >= screen_width - 5 || y < 5 || y >= screen_height - 5)
        begin
            red   = max_red;
            green = max_green;
            blue  = max_blue;
        end
        else
        begin
            // Blue objects
            for (int i = 0; i < 6; i++)
                if (x >= x_blue[i] && x < x_blue[i] + wx && y >= y_blue[i] && y < y_blue[i] + wy)
                    blue = max_blue;

            // Green objects
            for (int i = 0; i < 9; i++) // Now checking 9 green objects
                if (x >= x_green[i] && x < x_green[i] + wx && y >= y_green[i] && y < y_green[i] + wy)
                    green = max_green;

            // Red object
            if (x >= x_red && x < x_red + wx && y >= y_red && y < y_red + wy)
                red = max_red;
        end
    end

endmodule
