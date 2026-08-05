`timescale 1ns/1ps

module tb_i2c_master;


reg clk;
reg rst;
reg start;
reg [7:0] tx_byte;

tri1 sda;
tri1 sck;
wire done;
wire ack_error;

reg slave_drive;


i2c_master dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .tx_byte(tx_byte),
    .sda(sda),
    .sck(sck),
    .done(done),
    .ack_error(ack_error)
);


assign sda = (slave_drive) ? 1'b0 : 1'bz;

initial
    clk = 0;

always
    #41.666 clk = ~clk;

initial begin

    rst = 0;
    start = 0;
    tx_byte = 8'hA5;
    slave_drive = 0;

    #500;
    rst = 1;

    #2000;

    start = 1;
    #5000;
    start = 0;

    wait(dut.ack_en);

    slave_drive = 1;

    wait(dut.ack_done);

    slave_drive = 0;

    wait(done);

    #5000;

    $finish;

end

endmodule
