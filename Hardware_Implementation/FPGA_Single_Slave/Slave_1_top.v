
module slave_top
#(
    parameter SLAVE_ADDR = 7'h3C
)
(
    input        clk,      // 100 MHz System Clock (FPGA Pin F14)
    input        btn_rst,  // Reset Button (FPGA Pin H2)
    input        scl,      // I2C SCL Pin (PMOD A)
    inout        sda,      // I2C SDA Pin (PMOD A)
    input  [7:0] sw,       // FPGA Slide Switches (Inputs sent to Master)
    output [7:0] ld        // Local LED mirror for switch visualization
);

    wire rst_n = ~btn_rst; 


    assign ld = sw;


    i2c_slave_model #(
        .SLAVE_ADDR(SLAVE_ADDR)
    ) u_i2c_slave (
        .clk         (clk),
        .rst_n       (rst_n),
        .scl         (scl),
        .sda         (sda),
        .sensor_data (sw),
        .display_data()     // Unused for Slave 1
    );

endmodule