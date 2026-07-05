module slave_start(
    input clk,
    input rst,
    input sda,
    input sck,
    output reg done
);

  reg sda_prev;

  always @(posedge clk or negedge rst)
  begin
    if(!rst) begin
      sda_prev <= 1'b1;
      done     <= 1'b0;
    end
    else begin
      done <= 1'b0;
      if(sda_prev && !sda && sck)
        done <= 1'b1;
      sda_prev <= sda;
    end
  end

endmodule
