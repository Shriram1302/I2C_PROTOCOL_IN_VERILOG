`timescale 1ns/1ps

module tb_read_byte;

reg clk;
reg rst;
reg stat_en;

wire sda;
wire sck;
wire done;
wire [7:0] rx_byte;


reg slave_drive;

reg [7:0] tx_byte;
integer i;
-
read_byte dut(
    .stat_en(stat_en),
    .clk(clk),
    .rst(rst),
    .rx_byte(rx_byte),
    .sda(sda),
    .sck(sck),
    .done(done)
);


assign sda = slave_drive ? 1'b0 : 1'bz;

pullup(sda);
pullup(sck);


initial
    clk = 0;

always
    #1250 clk = ~clk;


initial begin

    slave_drive = 0;
    tx_byte = 8'hA5;      

    wait(stat_en);

    for(i=7;i>=0;i=i-1) begin


        @(negedge sck);

        if(tx_byte[i] == 1'b0)
            slave_drive = 1;      
        else
            slave_drive = 0;     

        @(posedge sck);

    end

    slave_drive = 0;

end


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
