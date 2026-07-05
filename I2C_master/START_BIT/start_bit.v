module start_i2c(input stat_en,
                 input clk,
                 input rst,
                 inout sda,
                 inout sck,
                 output reg done);

  reg [1:0]sts;
  reg sda_d_low;
  reg sck_d_low;
  
  localparam IDEL = 2'b00;
  localparam START = 2'b01;
  localparam H_START = 2'b11;
  
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
          IDEL:begin 
            sda_d_low<=0;
            sck_d_low<=0;
            done<=0;
            if(stat_en)
              sts<=START;
          end
          START: begin 
            sda_d_low<=1;
            sck_d_low<=0;
            sts<=H_START;
            
          end
          H_START: begin 
            sda_d_low<=1;
            sck_d_low<=0;
            done<=1;
            sts<=IDEL;
          end
          default: 
             sts<=IDEL;
        endcase 
      end
    end
endmodule 
         