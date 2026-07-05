module send_byte(input stat_en,
                 input clk,
                 input rst,
                 input [7:0] tx_byte,
                 inout sda,
                 inout sck,
                 output reg done);

  reg [2:0] sts;
  reg [2:0] count;
  reg sda_d_low;
  reg sck_d_low;

  localparam IDEL   = 3'b000;
  localparam LOAD   = 3'b001;
  localparam SETUP  = 3'b101; // NEW: SDA stable, SCK still low
  localparam SEND_B = 3'b010;
  localparam CHECK  = 3'b011;
  localparam FINISH = 3'b100;

  assign sda = sda_d_low ? 1'b0 : 1'bz;
  assign sck = sck_d_low ? 1'b0 : 1'bz;

  always @(posedge clk or negedge rst)
    begin
      if (!rst) begin
        sts       <= IDEL;
        sda_d_low <= 0;
        sck_d_low <= 0;
        count     <= 3'b111;
        done      <= 0;
      end
      else begin
        done <= 0;
        if (!stat_en && sts != FINISH) begin
          sts       <= IDEL;
          sda_d_low <= 0;
          sck_d_low <= 0;
          count     <= 3'b111;
        end
        else begin
          case (sts)
            IDEL: begin
              sda_d_low <= 0;
              sck_d_low <= 0;
              count     <= 3'b111;
              if (stat_en)
                sts <= LOAD;
            end
            LOAD: begin
              sck_d_low <= 1;               // SCK low
              sda_d_low <= !tx_byte[count]; // SDA changes now
              sts <= SETUP;
            end
            SETUP: begin
              sck_d_low <= 1;               // SCK still low - SDA settles
              sda_d_low <= !tx_byte[count];
              sts <= SEND_B;
            end
            SEND_B: begin
              sda_d_low <= !tx_byte[count];
              sck_d_low <= 0;               // SCK rises - slave samples SDA
              sts <= CHECK;
            end
            CHECK: begin
              sda_d_low <= !tx_byte[count];
              sck_d_low <= 1;               // SCK low - end of bit
              if (count == 0)
                sts <= FINISH;
              else begin
                count <= count - 1;
                sts   <= LOAD;
              end
            end
            FINISH: begin
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