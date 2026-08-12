`timescale 1ns/1ps

module tb_i2c_two_slaves;

  reg clk;
  reg rst;
  reg start;
  reg rw;
  reg [6:0] slave_addr;
  reg [7:0] reg_addr;
  reg [7:0] tx_data;
  wire [7:0] rx_data;
  wire done;
  wire ack_error;

  wire sda;
  wire sck;

  integer pass_count;
  integer fail_count;


  pullup (sda);
  pullup (sck);

  i2c_master dut (
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


  i2c_slave #(
    .SLAVE_ADDR(7'h3C)
  ) slave1_magnetometer (
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .sck(sck)
  );


  i2c_slave #(
    .SLAVE_ADDR(7'h0D)
  ) slave2_oled (
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .sck(sck)
  );

  initial clk = 0;
  always #10 clk = ~clk; 

 
  task do_transaction(input r_w, input [6:0] addr, input [7:0] rega,
                       input [7:0] wdata, input [7:0] expected_rdata,
                       input use_check);
    begin
      @(posedge clk);
      slave_addr = addr;
      reg_addr   = rega;
      tx_data    = wdata;
      rw         = r_w; 
      start      = 1;
      @(posedge clk);
      start      = 0;

      if (done)
        @(negedge done);
      @(posedge done);

      if (r_w == 1'b0) begin
        $display("[%0t] WRITE  addr=%h reg=%h data=%h  ack_error=%0d",
                  $time, addr, rega, wdata, ack_error);
        if (ack_error)
          fail_count = fail_count + 1;
        else
          pass_count = pass_count + 1;
      end
      else begin
        $display("[%0t] READ   addr=%h reg=%h rx_data=%h  ack_error=%0d",
                  $time, addr, rega, rx_data, ack_error);
        if (use_check) begin
          if (!ack_error && rx_data == expected_rdata) begin
            $display("        -> PASS (expected %h)", expected_rdata);
            pass_count = pass_count + 1;
          end
          else begin
            $display("        -> FAIL (expected %h)", expected_rdata);
            fail_count = fail_count + 1;
          end
        end
      end

      repeat(2) @(posedge clk);
    end
  endtask

  initial begin
    rst        = 0;
    start      = 0;
    rw         = 0;
    slave_addr = 7'h00;
    reg_addr   = 8'h00;
    tx_data    = 8'h00;
    pass_count = 0;
    fail_count = 0;

    // Pulse reset
    repeat (10) @(posedge clk);
    rst = 1;
    repeat (5) @(posedge clk);

    $display("\n===== Slave 1 (Magnetometer, 0x3C) =====");

    do_transaction(1'b0, 7'h3C, 8'h00, 8'h1D, 8'h00, 1'b0);

    do_transaction(1'b1, 7'h3C, 8'h00, 8'h00, 8'h1D, 1'b1);

    do_transaction(1'b0, 7'h3C, 8'h01, 8'h34, 8'h00, 1'b0);

    do_transaction(1'b1, 7'h3C, 8'h01, 8'h00, 8'h34, 1'b1);


    $display("\n===== Slave 2 (OLED Display, 0x0D) =====");

    do_transaction(1'b0, 7'h0D, 8'h05, 8'hFF, 8'h00, 1'b0);

    do_transaction(1'b1, 7'h0D, 8'h05, 8'h00, 8'hFF, 1'b1);


    do_transaction(1'b0, 7'h0D, 8'h06, 8'h12, 8'h00, 1'b0);

    do_transaction(1'b1, 7'h0D, 8'h06, 8'h00, 8'h12, 1'b1);

    #200;
    $display("\n===== SUMMARY: %0d passed, %0d failed =====", pass_count, fail_count);
    $finish;
  end

  initial begin
    $dumpfile("i2c_two_slaves_tb.vcd");
    $dumpvars(0, tb_i2c_two_slaves);
  end

endmodule
