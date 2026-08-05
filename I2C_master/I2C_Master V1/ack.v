

module ack(input clk,
           input rst,
           input stat_en,
           inout sda,
           output reg ack,
           output sck,
           output reg done);

  reg [2:0] sts;
  reg sda_d_low;
  reg sck_d_low;

  localparam IDEL  = 3'b000;
  localparam R_SDA = 3'b001;
  localparam CLK_H = 3'b010;
  localparam S_ACK = 3'b011;
  localparam CLK_L = 3'b100;
  localparam DONE  = 3'b101;

  assign sda = sda_d_low ? 1'b0 : 1'bz;
  assign sck = sck_d_low ? 1'b0 : 1'bz;

  always @(posedge clk or negedge rst)
    begin
      if (!rst) begin
        sts       <= IDEL;
        sda_d_low <= 0;
        sck_d_low <= 0;
        ack       <= 0;
        done      <= 0;
      end
      else begin
        done <= 0;
        if (!stat_en && sts != DONE) begin
          sts       <= IDEL;
          sda_d_low <= 0;
          sck_d_low <= 0;
        end
        else begin
          case (sts)
            IDEL: begin
              sda_d_low <= 0;
              sck_d_low <= 0;
              if (stat_en)
                sts <= R_SDA;
            end
            R_SDA: begin
              sda_d_low <= 0;
              sck_d_low <= 1; 
              sts <= CLK_H;
            end
            CLK_H: begin
              sda_d_low <= 0;
              sck_d_low <= 0;
            end
            S_ACK: begin
              ack <= (sda == 1'b0) ? 1'b1 : 1'b0;
              sts <= CLK_L;
            end
            CLK_L: begin
              sda_d_low <= 0;
              sck_d_low <= 1; 
              sts <= DONE;
            end
            DONE: begin
              sda_d_low <= 0;
              sck_d_low <= 0; 
              done      <= 1;
              sts <= IDEL;
            end
            default:
              sts <= IDEL;
          endcase
        end
      end
    end

endmodule
