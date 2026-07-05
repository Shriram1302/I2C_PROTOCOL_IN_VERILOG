module slave_receive_byte(input stat_en,
                          input clk,
                          input rst,
                          input sda,
                          input sck,
                          output reg [7:0] rx_byte,
                          output reg done);
  
  localparam IDLE           = 3'd0;
  localparam WAIT_SCL_HIGH  = 3'd1;
  localparam SAMPLE_BIT     = 3'd2;
  localparam CHECK_COUNT    = 3'd3;
  localparam DONE           = 3'd4;
  localparam WAIT_EN_LOW    = 3'd5;
  
  reg [2:0]sts;
  reg [2:0]count;
  reg sck_prev;
  
  always @(posedge clk or negedge rst)
    begin 
      if(!rst)begin
        count   <= 3'd7;
        rx_byte <= 8'h00;
        done    <= 0;
        sck_prev <= 0;
        sts     <= IDLE;
      end
      else begin
        done     <= 0;
        sck_prev <= sck;
        if(!stat_en && sts != WAIT_EN_LOW)begin
          sts <= IDLE;
          count <= 3'd7;
          rx_byte <= 8'h00;
          done <= 0;
        end
        else begin 
          case(sts)
            IDLE : begin
              count <= 3'd7;
              if(stat_en)
                sts <= WAIT_SCL_HIGH;
            end
            WAIT_SCL_HIGH: begin
              if(!sck_prev && sck)
                sts <= SAMPLE_BIT;
            end
            SAMPLE_BIT: begin 
              rx_byte[count] <= sda;
              sts <= CHECK_COUNT;
            end
            CHECK_COUNT: begin
              if(!sck) begin 
                if(count == 0)
                  sts <= DONE;
                else begin 
                  count <= count-1;
                  sts <= WAIT_SCL_HIGH;
                end
              end
            end
            DONE : begin 
              done <= 1;
              rx_byte <= 8'd0;
              sts  <= WAIT_EN_LOW;
            end 
            WAIT_EN_LOW : begin
              if(!stat_en)
                sts <= IDLE;
            end
            default: begin
              count   <= 3'd7;
              rx_byte <= 8'h00;
              done    <= 1'b0;
              sts <= IDLE;
            end
          endcase
        end
      end
    end
endmodule
