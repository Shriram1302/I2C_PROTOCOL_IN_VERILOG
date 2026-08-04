`timescale 1ns/1ps
module tb_i2c_two_slaves;

  reg clk;
  reg rst;
  reg start;
  reg rw;
  reg [6:0] slave_addr;
  reg [7:0] reg_addr;
  reg [7:0] tx_data;
  reg [7:0] rd_len;          
  wire [7:0] rx_data;
  wire rx_valid;             
  wire done;
  wire ack_error;

  wire sda;
  wire sck;

  integer pass_count;
  integer fail_count;
  integer byte_idx;          

  // Open-drain bus pull-ups
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
    .rd_len(rd_len),
    .sda(sda),
    .sck(sck),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .done(done),
    .ack_error(ack_error)
  );

  // Slave 1: magnetometer, address 0x3C
  i2c_slave_model #(
    .SLAVE_ADDR(7'h3C)
  ) slave1_magnetometer (
    .scl(sck),
    .sda(sda)
  );

  // Slave 2: OLED display, address 0x0D
  i2c_slave_model #(
    .SLAVE_ADDR(7'h0D)
  ) slave2_oled (
    .scl(sck),
    .sda(sda)
  );

  // 100 MHz system clock (10ns period) feeding the internal clock_divider
  initial clk = 0;
  always #1250 clk = ~clk;

  // Task updated to handle multi-byte validation arrays dynamically
  task do_transaction(input r_w, input [6:0] addr, input [7:0] rega,
                       input [7:0] wdata, input [7:0] length, 
                       input use_check);
    reg [7:0] expected_data;
    begin
      @(posedge clk);
      slave_addr = addr;
      reg_addr   = rega;
      tx_data    = wdata;
      rd_len     = length;    
      rw         = r_w;
      start      = 1;
      @(posedge clk);
      start      = 0;

      if (done)
        @(negedge done);

      if (r_w == 1'b0) begin
        @(posedge done);
        $display("[%0t] WRITE  addr=%h reg=%h data=%h  ack_error=%0d",
                  $time, addr, rega, wdata, ack_error);
        if (ack_error)
          fail_count = fail_count + 1;
        else
          pass_count = pass_count + 1;
      end
      else begin
        // For READ, dynamically capture streaming bytes on rx_valid
        byte_idx = 0;
        fork
          begin : capture_stream
            while (!done) begin
              @(posedge clk);
              if (rx_valid) begin
                // Assign expected test data array based on byte index profile
                case (byte_idx)
                  0: expected_data = 8'h11; // X_L
                  1: expected_data = 8'h22; // X_H
                  2: expected_data = 8'h33; // Y_L
                  3: expected_data = 8'h44; // Y_H
                  4: expected_data = 8'h55; // Z_L
                  5: expected_data = 8'h66; // Z_H
                  default: expected_data = 8'h00;
                endcase

                $display("[%0t] READ BYTE [%0d]  addr=%h reg=%h rx_data=%h  ack_error=%0d",
                          $time, byte_idx, addr, rega, rx_data, ack_error);
                
                if (use_check) begin
                  if (!ack_error && (rx_data == expected_data)) begin
                    $display("        -> BYTE [%0d] PASS (Expected data match: %h)", byte_idx, expected_data);
                    pass_count = pass_count + 1;
                  end
                  else begin
                    $display("        -> BYTE [%0d] FAIL (Mismatched or error data. Expected: %h)", byte_idx, expected_data);
                    fail_count = fail_count + 1;
                  end
                end
                byte_idx = byte_idx + 1;
                
                // Keep-lock structure to wait out the extended width of the slow rx_valid strobe
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
      end
      @(posedge clk);
    end
  endtask

  initial begin
    rst        = 0;
    start      = 0;
    rw         = 0;
    slave_addr = 7'h00;
    reg_addr   = 8'h00;
    tx_data    = 8'h00;
    rd_len     = 8'h00;
    pass_count = 0;
    fail_count = 0;

    // hold reset for a few clocks
    repeat (4) @(posedge clk);
    rst = 1;
    repeat (2) @(posedge clk);

    // =================================================================
    // Test 1 - Write (Write one byte)
    // Sequence: START -> 0x3C+W -> ACK -> 0x00 -> ACK -> 0x55 -> ACK -> STOP
    // =================================================================
    $display("\n===== TEST 1: Single-Byte Write =====");
    do_transaction(
      .r_w(1'b0), 
      .addr(7'h3C), 
      .rega(8'h00), 
      .wdata(8'h55), 
      .length(8'd0), 
      .use_check(1'b0)
    );

    // =================================================================
    // Test 2 - Read (Read one byte)
    // Sequence: START -> 0x3C+W -> ACK -> Reg -> ACK -> RepSTART -> 0x3C+R -> ACK -> Read Byte -> NACK -> STOP
    // =================================================================
    $display("\n===== TEST 2: Single-Byte Read =====");
    // Setting pointer index address location to 0x00 first inside the slave
    do_transaction(1'b0, 7'h3C, 8'h00, 8'h00, 8'd0, 1'b0);
    
    // Now trigger read transaction (Reads out index 0x00 = 8'h11)
    do_transaction(
      .r_w(1'b1), 
      .addr(7'h3C), 
      .rega(8'h00), 
      .wdata(8'h00), 
      .length(8'd1),            
      .use_check(1'b1)
    );

    // =================================================================
    // Test 3 - Multi-byte Read (Read X_L, X_H, Y_L, Y_H, Z_L, Z_H)
    // Sequence: Stream 6 consecutive bytes out of the device continuously
    // =================================================================
    $display("\n===== TEST 3: Multi-Byte Read (6 Bytes: X_L to Z_H) =====");
    // Setting pointer index address location back to 0x00 for fresh alignment
    do_transaction(1'b0, 7'h3C, 8'h00, 8'h00, 8'd0, 1'b0);

    // Streams out 6 bytes sequentially starting from index 0x00 (0x11, 0x22, 0x33, etc.)
    do_transaction(
      .r_w(1'b1), 
      .addr(7'h3C), 
      .rega(8'h00),             
      .wdata(8'h00), 
      .length(8'd6),            
      .use_check(1'b1)
    );

    #200;
    $display("\n===== TEST SUMMARY: %0d assertions passed, %0d assertions failed =====", pass_count, fail_count);
    $finish;
  end

  initial begin
    $dumpfile("i2c_two_slaves_tb.vcd");
    $dumpvars(0, tb_i2c_two_slaves);
  end

endmodule