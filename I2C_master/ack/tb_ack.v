`timescale 1ns/1ps

module tb_ack;

reg clk;
reg rst;
reg stat_en;

wire sda;
wire sck;
wire ack;
wire done;


reg slave_drive;


ack u1 (clk,rst,stat_en,sda,ack,sck,done);


assign sda = (slave_drive) ? 1'b0 : 1'bz;


always #1250 clk = ~clk;

initial begin


    clk = 0;
    rst = 0;
    stat_en = 0;
    slave_drive = 0;


    #20;
    rst = 1;



    #20;
    stat_en = 1;


    slave_drive = 0;


    @(posedge sck);


    slave_drive = 1;

 
    @(negedge sck);

    slave_drive = 0;

   
    #20;
    stat_en = 0;

    
    #50;



    stat_en = 1;


    slave_drive = 0;

    @(posedge sck);
    @(negedge sck);

    #20;
    stat_en = 0;

    #100;

    $finish;

end



endmodule