module i2c_master(input clk,
                  input rst,
                  input start,
                  input [7:0] tx_byte,
                  inout sda,
                  inout sck,
                  output reg done,
                  output reg ack_error);
  wire clk_4;
  wire start_done;
  wire byte_done;
  wire ack_done;
  wire stop_done;
  wire ack_received;
  
  reg [2:0]sts;
  reg start_en;
  reg byte_en;
  reg ack_en;
  reg stop_en;
  
  localparam IDEL = 3'b000;
  localparam START_M = 3'b001;
  localparam SEND_BYTE_M = 3'b010;
  localparam ACK_M = 3'b011;
  localparam STOP_M = 3'b100;
  localparam DONE = 3'b101;
  
  clock_divider u_dclock (
    .clk(clk),
    .out_clk(clk_4)
  );
  
  start_i2c u_start (
    .stat_en(start_en),
    .clk(clk_4),
    .rst(rst),
    .sda(sda),
    .sck(sck),
    .done(start_done)
  );
  
  write_byte u_byte (
    .stat_en(byte_en),
    .clk(clk_4),
    .rst(rst),
    .tx_byte(tx_byte),
    .sda(sda),
    .sck(sck),
    .done(byte_done)
  );
  
  ack u_ack (
    .stat_en(ack_en),
    .clk(clk_4),
    .rst(rst),
    .sda(sda),
    .ack(ack_received),
    .sck(sck),
    .done(ack_done)
  );
  
  stop_i2c u_stop (
    .stat_en(stop_en),
    .clk(clk_4),
    .rst(rst),
    .sda(sda),
    .sck(sck),
    .done(stop_done)
  );
  
  
  always @(posedge clk_4 or negedge rst)
    begin 
      if(!rst)begin 
        start_en<=0;
        byte_en<=0;
        ack_en<=0;
        stop_en<=0;
        done<=0;
        ack_error<=0;
        sts <= IDEL;
      end
      else begin 
        done<=0;
        start_en <= 0;
        byte_en  <= 0;
        ack_en   <= 0;
        stop_en  <= 0;
        case(sts)
          IDEL:begin
            start_en<= 0;
            byte_en<= 0;
            ack_en<= 0;
            stop_en<= 0;
            ack_error <= 0;
            if(start)
              sts<=START_M;
          end
          START_M: begin 
            start_en<=1;
            if(start_done)begin
              sts<=SEND_BYTE_M;
            end
          end
          SEND_BYTE_M: begin 
            byte_en<= 1;
            if(byte_done)begin
              sts<=ACK_M;
            end
          end
          ACK_M: begin
            ack_en   <= 1;
            if (ack_done) begin
              if (ack_received)
                sts <= STOP_M;
              else begin
                ack_error <= 1;
                sts <= IDEL;
              end
            end
          end
          STOP_M: begin 
            stop_en<= 1;
            if(stop_done)begin
              sts<=DONE;
            end
          end
          DONE: begin 
            done<=1;
            ack_error<=0;
            sts<=IDEL;
          end
          default: begin
                start_en <= 0;
                byte_en  <= 0;
                ack_en   <= 0;
                stop_en  <= 0;
                done     <= 0;
                ack_error<= 0;
                sts      <= IDEL;
          end
        endcase
      end
    end
endmodule