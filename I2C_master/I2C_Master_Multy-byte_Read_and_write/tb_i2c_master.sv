`timescale 1ns/1ps
module tb_i2c_two_slaves;

  reg clk;
  reg rst;
  reg start;
  reg rw;
  reg [6:0] slave_addr;
  reg [7:0] reg_addr;
  reg [7:0] tx_buffer [0:255];
  reg [7:0] rd_len;
  reg [7:0] wr_len;
  wire [7:0] rx_data;
  wire rx_valid;
  wire done;
  wire ack_error;

  wire sda;
  wire sck;

  integer pass_count;
  integer fail_count;
  integer byte_idx;
  integer k;

  reg [7:0] expected_buffer [0:255];


  pullup (sda);
  pullup (sck);

  i2c_master dut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .rw(rw),
    .slave_addr(slave_addr),
    .reg_addr(reg_addr),
    .tx_buffer(tx_buffer),
    .rd_len(rd_len),
    .wr_len(wr_len),
    .sda(sda),
    .sck(sck),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .done(done),
    .ack_error(ack_error)
  );


  i2c_slave_model #(
    .SLAVE_ADDR(7'h3C)
  ) slave1_magnetometer (
    .scl(sck),
    .sda(sda)
  );


  initial clk = 0;
  always #1250 clk = ~clk;

  task do_write(input [6:0] addr, input [7:0] rega, input [7:0] wlen);
    begin
      @(posedge clk);
      slave_addr = addr;
      reg_addr   = rega;
      wr_len     = wlen;
      rd_len     = 8'd0;
      rw         = 1'b0;
      start      = 1;
      @(posedge clk);
      start      = 0;

      @(posedge done);
      $display("[%0t] WRITE  addr=%h reg=%h wr_len=%0d  ack_error=%0d",
                $time, addr, rega, wlen, ack_error);

      if (ack_error)
        fail_count = fail_count + 1;
      else
        pass_count = pass_count + 1;

      @(posedge clk);
    end
  endtask


  task do_read(input [6:0] addr, input [7:0] rega, input [7:0] rlen,
               input use_check);
    begin
      @(posedge clk);
      slave_addr = addr;
      reg_addr   = rega;
      rd_len     = rlen;
      wr_len     = 8'd0;
      rw         = 1'b1;
      start      = 1;
      @(posedge clk);
      start      = 0;

      byte_idx = 0;
      fork
        begin : capture_stream
          while (!done) begin
            @(posedge clk);
            if (rx_valid) begin
              $display("[%0t] READ BYTE [%0d]  addr=%h reg=%h rx_data=%h  ack_error=%0d",
                        $time, byte_idx, addr, rega, rx_data, ack_error);

              if (use_check) begin
                if (!ack_error && (rx_data == expected_buffer[byte_idx])) begin
                  $display("        -> BYTE [%0d] PASS (Expected: %h)",
                            byte_idx, expected_buffer[byte_idx]);
                  pass_count = pass_count + 1;
                end
                else begin
                  $display("        -> BYTE [%0d] FAIL (Expected: %h, Got: %h)",
                            byte_idx, expected_buffer[byte_idx], rx_data);
                  fail_count = fail_count + 1;
                end
              end
              byte_idx = byte_idx + 1;

              while (rx_valid && !done) begin
                @(posedge clk);
              end
            end
          end
        end
        begin : wait_for_done
          @(posedge done);
        end
      join

      @(posedge clk);
    end
  endtask

  initial begin
    rst        = 0;
    start      = 0;
    rw         = 0;
    slave_addr = 7'h00;
    reg_addr   = 8'h00;
    rd_len     = 8'h00;
    wr_len     = 8'h00;
    pass_count = 0;
    fail_count = 0;

    for (k = 0; k < 256; k = k + 1) begin
      tx_buffer[k]       = 8'h00;
      expected_buffer[k] = 8'h00;
    end

    // hold reset for a few clocks
    repeat (4) @(posedge clk);
    rst = 1;
    repeat (2) @(posedge clk);


    $display("\n===== TEST 1: Single-Byte Write =====");
    tx_buffer[0] = 8'h55;
    do_write(7'h3C, 8'h00, 8'd1);

    if (slave1_magnetometer.memory[0] == 8'h55) begin
      $display("        -> MEMORY CHECK PASS (memory[0]=%h)", slave1_magnetometer.memory[0]);
      pass_count = pass_count + 1;
    end
    else begin
      $display("        -> MEMORY CHECK FAIL (memory[0]=%h, expected 55)", slave1_magnetometer.memory[0]);
      fail_count = fail_count + 1;
    end


    $display("\n===== TEST 2: Multi-Byte Write (4 Bytes) =====");
    tx_buffer[0] = 8'h11;
    tx_buffer[1] = 8'h22;
    tx_buffer[2] = 8'h33;
    tx_buffer[3] = 8'h44;
    do_write(7'h3C, 8'h00, 8'd4);

    if (slave1_magnetometer.memory[0] == 8'h11 &&
        slave1_magnetometer.memory[1] == 8'h22 &&
        slave1_magnetometer.memory[2] == 8'h33 &&
        slave1_magnetometer.memory[3] == 8'h44) begin
      $display("        -> MEMORY CHECK PASS (memory[0:3]=%h %h %h %h)",
                slave1_magnetometer.memory[0], slave1_magnetometer.memory[1],
                slave1_magnetometer.memory[2], slave1_magnetometer.memory[3]);
      pass_count = pass_count + 1;
    end
    else begin
      $display("        -> MEMORY CHECK FAIL (memory[0:3]=%h %h %h %h)",
                slave1_magnetometer.memory[0], slave1_magnetometer.memory[1],
                slave1_magnetometer.memory[2], slave1_magnetometer.memory[3]);
      fail_count = fail_count + 1;
    end


    $display("\n===== TEST 3: Single-Byte Read =====");
    expected_buffer[0] = 8'h11;
    do_read(7'h3C, 8'h00, 8'd1, 1'b1);

    $display("\n===== TEST 4: Multi-Byte Read (6 Bytes) =====");
    slave1_magnetometer.memory[0] = 8'h11;
    slave1_magnetometer.memory[1] = 8'h22;
    slave1_magnetometer.memory[2] = 8'h33;
    slave1_magnetometer.memory[3] = 8'h44;
    slave1_magnetometer.memory[4] = 8'h55;
    slave1_magnetometer.memory[5] = 8'h66;

    expected_buffer[0] = 8'h11;
    expected_buffer[1] = 8'h22;
    expected_buffer[2] = 8'h33;
    expected_buffer[3] = 8'h44;
    expected_buffer[4] = 8'h55;
    expected_buffer[5] = 8'h66;

    do_read(7'h3C, 8'h00, 8'd6, 1'b1);

    #200;
    $display("\n===== TEST SUMMARY: %0d assertions passed, %0d assertions failed =====", pass_count, fail_count);
    $finish;
  end



endmodule
