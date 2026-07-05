`timescale 1ns/1ps

module tb_send_byte;

reg stat_en;
reg clk;
reg rst;
reg [7:0] tx_byte;

wire sda;
wire sck;
wire done;


send_byte u1 (stat_en,clk,rst,tx_byte,sda,sck,done);


initial begin
    clk = 0;
    forever #1250 clk = ~clk;
end;


initial begin


    rst     = 0;
    stat_en = 0;
    tx_byte = 8'b00000000;


    #100;
    rst = 1;


    #2500;
    tx_byte = 8'b10101101;
    stat_en = 1;

    #2500;
    stat_en = 0;


    @(posedge done);

    #5000;
    rst = 0;

    #2500;
    rst = 1;


    #2500;
    tx_byte = 8'b00011011;
    stat_en = 1;

    #2500;
    stat_en = 0;

    @(posedge done);

    #10000;
    $finish;

end


endmodule