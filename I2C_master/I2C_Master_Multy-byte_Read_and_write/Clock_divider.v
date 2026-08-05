module clock_divider(input clk,
                     
                    output reg out_clk=0);
parameter DIV=15;
reg[4:0] count=0;
  
  
  always @(posedge clk)
    begin
      if(count==DIV-1)begin
      count<=0;
      out_clk<=~out_clk;
      end
      else 
      count<=count+1;
    end
endmodule