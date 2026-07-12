module slave_send_byte(
    input stat_en,
    input clk,
    input rst,
    input [7:0] tx_byte,
    output sda_out,
    output sda_oe,
    input sck,
    output reg done
);

  reg [2:0] sts;
  reg [2:0] count;
  reg sda_d_low;
  reg sck_prev;

  localparam IDLE          = 3'd0;
  localparam SETUP_BIT     = 3'd1;
  localparam WAIT_SCL_HIGH = 3'd2;
  localparam WAIT_SCL_LOW  = 3'd3;
  localparam CHECK_COUNT   = 3'd4;
  localparam DONE          = 3'd5;
  localparam WAIT_EN_LOW   = 3'd6;

  assign sda_out = 1'b0;
  assign sda_oe  = sda_d_low;

  always @(posedge clk or negedge rst) begin
    if(!rst) begin
      sts       <= IDLE;
      count     <= 3'd7;
      sda_d_low <= 0;
      sck_prev  <= 0;
      done      <= 0;
    end
    else begin
      done     <= 1'b0;
      sck_prev <= sck;
      
      if(!stat_en && sts != WAIT_EN_LOW) begin
        sts       <= IDLE;
        count     <= 3'd7;
        sda_d_low <= 0;
      end
      else begin
        case(sts)
          IDLE: begin
            count     <= 3'd7;
            sda_d_low <= 0;
            if(stat_en)
              sts <= SETUP_BIT;
          end
          SETUP_BIT: begin
            sda_d_low <= !tx_byte[count];
            sts       <= WAIT_SCL_HIGH;
          end
          WAIT_SCL_HIGH: begin
            if(!sck_prev && sck)
              sts <= WAIT_SCL_LOW;
          end
          WAIT_SCL_LOW: begin
            if(sck_prev && !sck)
              sts <= CHECK_COUNT;
          end
          CHECK_COUNT: begin
            if(count == 0)
              sts <= DONE;
            else begin
              count <= count - 1;
              sts   <= SETUP_BIT;
            end
          end
          DONE: begin
            sda_d_low <= 0; 
            done      <= 1;
            sts       <= WAIT_EN_LOW;
          end
          WAIT_EN_LOW: begin
            if(!stat_en)
              sts <= IDLE;
          end
          default: sts <= IDLE;
        endcase
      end
    end
  end
endmodule