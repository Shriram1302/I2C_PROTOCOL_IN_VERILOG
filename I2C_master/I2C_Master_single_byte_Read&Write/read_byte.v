module read_byte(input stat_en,
                 input clk,
                 input rst,
                 output reg [7:0] rx_byte,
                 inout sda,
                 inout sck,
                 output reg done);

  reg [2:0] sts;
  reg [2:0] count;
  reg sda_d_low;
  reg sck_d_low;

  localparam IDEL   = 3'b000;
  localparam LOAD   = 3'b001;
  localparam CLK_H  = 3'b101; 
  localparam SAMPLE = 3'b010;
  localparam CHECK  = 3'b011;
  localparam FINISH = 3'b100;
  localparam WAIT_EN_LOW = 3'b110;

  assign sda = sda_d_low ? 1'b0 : 1'bz;
  assign sck = sck_d_low ? 1'b0 : 1'bz;

  always @(posedge clk or negedge rst)
    begin
      if (!rst) begin
        sts       <= IDEL;
        sda_d_low <= 0;
        sck_d_low <= 0;
        rx_byte <= 8'h00;
        count     <= 3'b111;
        done      <= 0;
      end
      else begin
        done <= 0;
        if (!stat_en && sts != FINISH && sts != WAIT_EN_LOW) begin
          sts       <= IDEL;
          sda_d_low <= 0;
          sck_d_low <= 0;
          count     <= 3'b111;
        end
        else begin
          case (sts)
            IDEL: begin
              // FIX: same immediate-handoff race as ack.v/send_byte.v -
              // ack (or repeated_start) hands off to read_byte while
              // holding SCK low; if stat_en is already asserted this
              // cycle, keep holding instead of releasing to avoid a
              // spurious extra clock edge.
              sda_d_low <= 0;
              sck_d_low <= stat_en ? 1'b1 : 1'b0;
              count     <= 3'b111;
              if (stat_en)
                sts <= LOAD;
            end
            LOAD: begin
              sda_d_low <= 0;
              sck_d_low <= 1;
              sts <= CLK_H;
            end
            CLK_H: begin
              sda_d_low <= 0;
              sck_d_low <= 0;
              sts <= SAMPLE;
            end
            SAMPLE: begin
              sda_d_low <= 0;
              rx_byte[count] <= sda;
              sts <= CHECK;
            end
            CHECK: begin
              sda_d_low <= 0;
              sck_d_low <= 1;
              if (count == 0)
                sts <= FINISH;
              else begin
                count <= count - 1;
                sts   <= LOAD;
              end
            end
            FINISH: begin
              sda_d_low <= 0;
              sck_d_low <= 1;
              done      <= 1;
              sts <= WAIT_EN_LOW;
            end
            WAIT_EN_LOW: begin
              sda_d_low <= 0;
              sck_d_low <= 1;
              if (!stat_en)
                sts <= IDEL;
            end
            default:
              sts <= IDEL;
          endcase
        end
      end
    end

endmodule