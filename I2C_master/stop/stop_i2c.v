module stop_i2c(input stat_en,
                 input clk,
                 input rst,
                 inout sda,
                 inout sck,
                 output reg done);

  reg [2:0]sts;
  reg sda_d_low;
  reg sck_d_low;
  
  localparam IDEL = 3'b000;
  localparam PREPARE = 3'b001;
  localparam SCL_H = 3'b010;
  localparam STOP = 3'b011;
  localparam DONE = 3'b100;
  
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
              sts<=PREPARE;
          end
          PREPARE: begin 
            sda_d_low<=1;
            sck_d_low<=1;
            sts<=SCL_H;
          end
          SCL_H: begin 
            sda_d_low<=1;
            sck_d_low<=0;
            sts<=STOP;
          end
          STOP: begin 
            sda_d_low<=0;
            sck_d_low<=0;
            sts<=DONE;
          end
          DONE: begin 
            done<=1;
            sda_d_low <= 0;
            sck_d_low <= 0;
            sts<=IDEL;
          end
          default: 
             sts<=IDEL;
        endcase 
      end
    end
endmodule 
         