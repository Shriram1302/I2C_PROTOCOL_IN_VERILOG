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
  localparam SETUP  = 3'b101; // SDA stable, SCK still low
  localparam SEND_B = 3'b010;
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
              // FIX: previously this unconditionally released SCK
              // (sck_d_low <= 0) here. start_i2c hands off to send_byte
              // while holding BOTH sda and sck low. Since byte_en is
              // already high the very cycle this IDEL state runs (an
              // immediate handoff, not genuine bus-idle time), releasing
              // both sda and sck together in the same cycle makes them
              // rise simultaneously - a race the slave's edge-triggered
              // STOP detector (posedge sda while scl==1) can catch as a
              // false STOP condition after just one address bit.
              //
              // If stat_en is already asserted on entry, keep SCK held
              // low instead of releasing it; LOAD takes over the
              // bit-clock sequencing safely from there. Only release SCK
              // here when send_byte is genuinely idle (stat_en low).
              sda_d_low <= 0;
              sck_d_low <= stat_en ? 1'b1 : 1'b0;
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
              sck_d_low <= 1;               // hold SCK low - clean handoff to ack
              done      <= 1;
              sts <= WAIT_EN_LOW;
            end
            WAIT_EN_LOW: begin
              sda_d_low <= 0;
              sck_d_low <= 1;
              // hold here until i2c_master deasserts stat_en, so we
              // don't race back into LOAD while stat_en is still high
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