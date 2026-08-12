`timescale 1ns/1ps

module tb_sent_bit;

reg clk;
reg rst;
reg stat_en;
reg bit_data;

wire sda;
wire sck;
wire done;


sent_bit uut (
    .stat_en(stat_en),
    .clk(clk),
    .rst(rst),
    .bit_data(bit_data),
    .sda(sda),
    .sck(sck),
    .done(done)
);


initial begin
    clk = 0;
    forever #1250 clk = ~clk;   
end

initial begin


    rst      = 0;
    stat_en  = 0;
    bit_data = 0;


    #5000;
    rst = 1;


    #5000;
    bit_data = 1;
    stat_en  = 1;

    #2500;
    stat_en  = 0;

    // Wait
    #15000;


    bit_data = 0;
    stat_en  = 1;

    #2500;
    stat_en  = 0;

    
    #15000;

    $finish;
end




endmodule
