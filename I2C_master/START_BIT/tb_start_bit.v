`timescale 1ns/1ps

module tb_start_i2c;

reg stat_en;
reg clk;
reg rst;

wire sda;
wire sck;
wire done;

start_i2c u1(
    .stat_en(stat_en),
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .sck(sck),
    .done(done)
);

initial begin
    clk = 0;
    forever #1250 clk = ~clk;
end


initial begin
    rst = 0;
    stat_en = 0;

    #100;
    rst = 1;

    #5000;
    stat_en = 1;

    #5000;
    stat_en = 0;

    #20000;
    $finish;
end

endmodule
