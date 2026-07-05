module master_nack(input clk,
           input rst,
           input stat_en,
           inout sda,
           inout sck,
           output reg done);
  
  reg [2:0]sts;
  reg sda_d_low;
  reg sck_d_low;
  
  localparam IDEL   = 3'b000;
  localparam SETUP  = 3'b001;
  localparam CLK_H  = 3'b010;
  localparam CLK_L  = 3'b011;
  localparam FINISH = 3'b100;
  localparam WAIT_EN_LOW = 3'b101;
 
  
  assign sda = sda_d_low? 1'b0 : 1'bz;
  assign sck = sck_d_low? 1'b0 : 1'bz;
  
  always @(posedge clk or negedge rst)
    begin 
      if(!rst)begin
        sts<=IDEL;
        sda_d_low <= 0;
        sck_d_low <= 0;
        done<=0;
      end
      else begin
        done<=0;
        case(sts)
          IDEL: begin
            sda_d_low <= 0;
            sck_d_low <= 0;
            done <= 0;
            if(stat_en)begin
              sts <= SETUP;
            end
          end
          SETUP: begin 
            sda_d_low <= 0;
            sck_d_low <= 1;
            sts <= CLK_H;
          end
          CLK_H: begin 
            sda_d_low <= 0;
            sck_d_low <= 0;
            sts <= CLK_L;
          end
          CLK_L: begin
            sda_d_low <= 0;
            sck_d_low <= 1;
            sts <= FINISH;
          end
          FINISH: begin 
            sda_d_low <= 0;
            sck_d_low <= 1;
            done<=1;
            sts <= WAIT_EN_LOW;
          end
          WAIT_EN_LOW: begin
            sda_d_low <= 0;
            sck_d_low <= 1;
            if(!stat_en)
              sts <= IDEL;
          end
          default: 
             sts<=IDEL; 
        endcase
      end
    end
endmodule
