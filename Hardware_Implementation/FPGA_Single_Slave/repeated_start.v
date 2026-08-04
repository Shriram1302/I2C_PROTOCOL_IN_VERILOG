module repeated_start(input stat_en,
                 input clk,
                 input rst,
                 inout sda,
                 inout sck,
                 output reg done);

  reg [2:0] sts;
  reg sda_d_low;
  reg sck_d_low;

  localparam IDEL        = 3'b000;
  localparam SCK_H       = 3'b001;
  localparam SDA_H       = 3'b010;
  localparam START       = 3'b011;
  localparam SCK_L       = 3'b100;
  localparam WAIT_EN_LOW = 3'b101;

  assign sda = sda_d_low ? 1'b0 : 1'bz;
  assign sck = sck_d_low ? 1'b0 : 1'bz;

  always @(posedge clk or negedge rst)
    begin
      if (!rst) begin
        sts       <= IDEL;
        sda_d_low <= 0;
        sck_d_low <= 0;
        done      <= 0;
      end
      else begin
        done <= 0;
        case (sts)
          IDEL: begin
            sda_d_low <= 0;
            sck_d_low <= 0;
            if (stat_en)
              sts <= SCK_H;
          end
          SCK_H: begin
            sda_d_low <= 0;
            sck_d_low <= 0; 
            sts <= SDA_H;
          end
          SDA_H: begin
            sda_d_low <= 0;
            sck_d_low <= 0;
            sts <= START;
          end
          START: begin
            sda_d_low <= 1; 
            sck_d_low <= 0; 
            sts <= SCK_L;
          end
          SCK_L: begin
            sck_d_low <= 1; 
            sda_d_low <= 1;
            done<=1;
            sts <= WAIT_EN_LOW;
            
          end
          WAIT_EN_LOW: begin
            sda_d_low <= 1; 
            sck_d_low <= 1; 
            if (!stat_en)
              sts <= IDEL;
          end
          default: begin
            sda_d_low <= 0;
            sck_d_low <= 0;
            done      <= 0;
            sts       <= IDEL;
          end
        endcase
      end
    end

endmodule
