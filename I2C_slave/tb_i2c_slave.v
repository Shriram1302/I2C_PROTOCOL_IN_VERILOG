`timescale 1ns / 1ps

module tb_i2c_top;

    // Testbench Global Signals
    reg clk;
    reg rst;
    
    // Master Control Signals
    reg start;
    reg rw;
    reg [6:0] slave_addr;
    reg [7:0] reg_addr;
    reg [7:0] tx_data;
    
    // Master Outputs
    wire [7:0] rx_data;
    wire done;
    wire ack_error;

    // I2C Bus Signals (Must use tri1 to emulate open-drain pull-up resistors)
    tri1 sda;
    tri1 sck;

    // Instantiate I2C Master
    i2c_master u_master (
        .clk(clk),
        .rst(rst),
        .start(start),
        .rw(rw),
        .slave_addr(slave_addr),
        .reg_addr(reg_addr),
        .tx_data(tx_data),
        .sda(sda),
        .sck(sck),
        .rx_data(rx_data),
        .done(done),
        .ack_error(ack_error)
    );

    // Instantiate I2C Slave
    i2c_slave #(
        .SLAVE_ADDR(7'h50) // Matching Master's target address
    ) u_slave (
        .clk(clk),
        .rst(rst),
        .sda(sda),
        .sck(sck)
    );

    // Clock Generation (50MHz System Clock)
    always #10 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk        = 0;
        rst        = 0;
        start      = 0;
        rw         = 0;
        slave_addr = 7'h50;
        reg_addr   = 8'h00;
        tx_data    = 8'h00;

        // Apply Reset
        #100;
        rst = 1;
        #100;

        // -------------------------------------------------------------
        // TRANSACTION 1: WRITE 8'hA5 TO REGISTER 8'h20
        // -------------------------------------------------------------
        $display("[TB] Starting I2C Write Transaction...");
        reg_addr   = 8'h20;   // Target register address inside slave
        tx_data    = 8'hA5;   // Data byte to write
        rw         = 1'b0;    // 0 = Write
        
        #20;
        start      = 1'b1;    // Trigger master start pulse
        #20;
        start      = 1'b0;

        // Wait for Master to complete write operation
        @(posedge done);
        #20;
        if (ack_error)
            $display("[TB] Error: Write transaction received a NACK!");
        else
            $display("[TB] Write transaction completed successfully.");

        #500; // Small delay between transactions

        // -------------------------------------------------------------
        // TRANSACTION 2: READ BACK FROM REGISTER 8'h20
        // -------------------------------------------------------------
        $display("[TB] Starting I2C Read Transaction...");
        reg_addr   = 8'h20;   // Target register address to read from
        rw         = 1'b1;    // 1 = Read[cite: 1]
        
        #20;
        start      = 1'b1;    // Trigger master start pulse
        #20;
        start      = 1'b0;

        // Wait for Master to complete read operation
        @(posedge done);
        #20;
        if (ack_error) begin
            $display("[TB] Error: Read transaction received a NACK!");
        end else begin
            $display("[TB] Read transaction completed successfully.");
            $display("[TB] Data read from Slave: 8'h%h (Expected: 8'hA5)", rx_data);
            
            // Verification Assertion
            if (rx_data === 8'hA5)
                $display("[TB] SUCCESS: Read data matches written data!");
            else
                $display("[TB] FAILURE: Mismatched data!");
        end

        // End Simulation
        #200;
        $finish;
    end

    // Optional Waveform Dumping (for tools like Icarus Verilog/GTKWave)
    initial begin
        $dumpfile("i2c_simulation.vcd");
        $dumpvars(0, tb_i2c_top);
    end

endmodule