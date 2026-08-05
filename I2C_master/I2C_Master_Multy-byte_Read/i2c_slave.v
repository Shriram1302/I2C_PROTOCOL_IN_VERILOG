module i2c_slave_model
#(
    parameter        SLAVE_ADDR = 7'h3C
)
(
    input  scl,
    inout  sda
);

  reg sda_drive;
  assign sda = sda_drive ? 1'b0 : 1'bz;


  localparam ST_IDLE     = 3'd0;
  localparam ST_ADDR     = 3'd1; 
  localparam ST_ADDR_ACK = 3'd2; 
  localparam ST_WR_BYTE  = 3'd3; 
  localparam ST_WR_ACK   = 3'd4; 
  localparam ST_RD_BYTE  = 3'd5; 
  localparam ST_RD_ACK   = 3'd6; 

  reg [2:0] state;
  reg [2:0] bit_idx;      
  reg [7:0] shift_in;      
  reg [7:0] cur_read_byte; 
  reg       is_read;       
  reg       matched;       
  
  
  reg [7:0] reg_file [0:7];
  reg [2:0] reg_ptr; 

  initial begin
    state         = ST_IDLE;
    bit_idx       = 3'd7;
    shift_in      = 8'h00;
    cur_read_byte = 8'h00;
    is_read       = 1'b0;
    matched       = 1'b0;
    reg_ptr       = 3'd0;
    sda_drive     = 1'b0;

   
    reg_file[0] = 8'h11; 
    reg_file[1] = 8'h22; 
    reg_file[2] = 8'h33; 
    reg_file[3] = 8'h44; 
    reg_file[4] = 8'h55; 
    reg_file[5] = 8'h66; 
    reg_file[6] = 8'h77; 
    reg_file[7] = 8'h88; 
  end

  always @(negedge sda) begin
    if (scl) begin
      state   <= ST_ADDR;
      bit_idx <= 3'd7;
    end
  end
  always @(posedge sda) begin
    if (scl) begin
      state <= ST_IDLE;
    end
  end
  always @(posedge scl) begin
    case (state)
      ST_ADDR: begin
        shift_in <= {shift_in[6:0], sda};
        if (bit_idx == 0) begin
          is_read <= sda;
          matched <= (shift_in[6:0] == SLAVE_ADDR);
          state   <= ST_ADDR_ACK;
        end
        else
          bit_idx <= bit_idx - 1'b1;
      end

      ST_ADDR_ACK: begin
        if (matched) begin
          if (is_read) begin
            cur_read_byte <= reg_file[reg_ptr]; 
            state   <= ST_RD_BYTE;
            bit_idx <= 3'd7;
          end
          else begin
            state   <= ST_WR_BYTE;
            bit_idx <= 3'd7;
          end
        end
        else
          state <= ST_IDLE; 
      end

      ST_WR_BYTE: begin
        shift_in <= {shift_in[6:0], sda};
        if (bit_idx == 0) begin
          state <= ST_WR_ACK;
        end
        else
          bit_idx <= bit_idx - 1'b1;
      end

      ST_WR_ACK: begin
        reg_ptr <= shift_in[2:0]; 
        state   <= ST_WR_BYTE;
        bit_idx <= 3'd7;
      end

      ST_RD_BYTE: begin
        if (bit_idx == 0)
          state <= ST_RD_ACK;
        else
          bit_idx <= bit_idx - 1'b1;
      end

      ST_RD_ACK: begin
        if (sda) begin
          state    <= ST_IDLE;
        end
        else begin
          reg_ptr       <= reg_ptr + 1'b1;
          cur_read_byte <= reg_file[reg_ptr + 1'b1]; 
          state         <= ST_RD_BYTE;
          bit_idx       <= 3'd7;
        end
      end

      default: state <= ST_IDLE;
    endcase
  end
  always @(negedge scl) begin
    case (state)
      ST_ADDR_ACK: sda_drive <= matched;          
      ST_WR_ACK:   sda_drive <= matched;          
      ST_RD_BYTE:  sda_drive <= !cur_read_byte[bit_idx];
      default:     sda_drive <= 1'b0;             
    endcase
  end

endmodule
