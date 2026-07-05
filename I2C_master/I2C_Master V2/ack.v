// Same architectural fix applied: ack returns to IDEL and releases
// the bus whenever stat_en drops, preventing it from clamping SCK
// during the STOP phase.
//
// Original bug: IDEL state set sck_d_low=1 (holding SCK low while idle).
// That was fixed previously. This fix adds stat_en gating so the module
// does not linger driving bus lines after the ACK window closes.

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
        // Return to IDEL and release bus when stat_en drops
        // (except in DONE where we are completing the handshake)
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
              // Release SDA so slave can pull it low for ACK
              sda_d_low <= 0;
              sck_d_low <= 1; // hold SCK low before rising edge
              sts <= CLK_H;
            end
            CLK_H: begin
              sda_d_low <= 0;
              sck_d_low <= 0; // release SCK: goes high, slave holds SDA
              sts <= S_ACK;
            end
            S_ACK: begin
              ack <= (sda == 1'b0) ? 1'b1 : 1'b0;
              sts <= CLK_L;
            end
            CLK_L: begin
              sda_d_low <= 0;
              sck_d_low <= 1; // pull SCK low to end ACK clock
              sts <= DONE;
            end
            DONE: begin
              sda_d_low <= 0;
              sck_d_low <= 0; // release bus before hand-off to stop_i2c
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