`timescale 1ns/1ps

module tb_master_nack;

reg clk;
reg rst;
reg stat_en;

wire sda;
wire sck;
wire done;

master_nack u1 (
    .clk(clk),
    .rst(rst),
    .stat_en(stat_en),
    .sda(sda),
    .sck(sck),
    .done(done)
);


pullup(sda);
pullup(sck);


initial
    clk = 1'b0;

always
    #1250 clk = ~clk;


initial begin

    rst     = 1'b0;
    stat_en = 1'b0;

    #5000;
    rst = 1'b1;

    #5000;


    stat_en = 1'b1;

    wait(done);

    #10000;


    stat_en = 1'b0;

    #10000;

    $finish;

end




endmodule