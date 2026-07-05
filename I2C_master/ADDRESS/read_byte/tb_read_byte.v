`timescale 1ns/1ps

module tb_read_byte;

reg clk;
reg rst;
reg stat_en;

wire sda;
wire sck;
wire done;
wire [7:0] rx_byte;

//------------------------------------
// Slave Drive
//------------------------------------
reg slave_drive;

// Byte to transmit from slave
reg [7:0] tx_byte;
integer i;

//------------------------------------
// DUT
//------------------------------------
read_byte dut(
    .stat_en(stat_en),
    .clk(clk),
    .rst(rst),
    .rx_byte(rx_byte),
    .sda(sda),
    .sck(sck),
    .done(done)
);

//------------------------------------
// Open Drain Bus
//------------------------------------
assign sda = slave_drive ? 1'b0 : 1'bz;

pullup(sda);
pullup(sck);

//------------------------------------
// 400 kHz Clock
//------------------------------------
initial
    clk = 0;

always
    #1250 clk = ~clk;

//------------------------------------
// Slave Data Generator
//------------------------------------
initial begin

    slave_drive = 0;
    tx_byte = 8'hA5;      //10100101

    wait(stat_en);

    // Send MSB first
    for(i=7;i>=0;i=i-1) begin

        // Wait until SCL goes LOW
        @(negedge sck);

        if(tx_byte[i] == 1'b0)
            slave_drive = 1;      //Drive LOW
        else
            slave_drive = 0;      //Release HIGH

        // Wait until SCL HIGH
        @(posedge sck);

    end

    slave_drive = 0;

end

//------------------------------------
// Test Sequence
//------------------------------------
initial begin

    rst = 0;
    stat_en = 0;

    #5000;
    rst = 1;

    #5000;

    stat_en = 1;

    wait(done);

    #5000;

    stat_en = 0;

    #10000;
    $finish;

end
endmodule