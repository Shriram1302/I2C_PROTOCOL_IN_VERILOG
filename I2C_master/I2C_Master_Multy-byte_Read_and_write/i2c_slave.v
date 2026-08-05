module i2c_slave_model
#(
    parameter        SLAVE_ADDR = 7'h3C
)
(
    input  scl,
    inout  sda
);

  // Open-drain bus drive
  reg sda_drive;
  assign sda = sda_drive ? 1'b0 : 1'bz;

  // FSM states (structure preserved from original model)
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

  // EEPROM-style internal memory (256 bytes) + 8-bit pointer
  reg [7:0] memory [0:255];
  reg [7:0] reg_ptr;      // Internal pointer tracking current read/write index
  reg       first_byte;   // 1 = next received byte is the register-pointer byte

  integer i;

  initial begin
    state         = ST_IDLE;
    bit_idx       = 3'd7;
    shift_in      = 8'h00;
    cur_read_byte = 8'h00;
    is_read       = 1'b0;
    matched       = 1'b0;
    reg_ptr       = 8'd0;
    first_byte    = 1'b1;
    sda_drive     = 1'b0;

    // Clear memory by default; testbench may pre-load specific
    // locations hierarchically before a transaction.
    for (i = 0; i < 256; i = i + 1)
      memory[i] = 8'h00;
  end

  // Asynchronous START detection
  always @(negedge sda) begin
    if (scl) begin
      state   <= ST_ADDR;
      bit_idx <= 3'd7;
    end
  end

  // Asynchronous STOP detection
  always @(posedge sda) begin
    if (scl) begin
      state <= ST_IDLE;
    end
  end

  // Latch inputs on SCL rising edge
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
            cur_read_byte <= memory[reg_ptr]; // Load byte at current pointer
            state         <= ST_RD_BYTE;
            bit_idx       <= 3'd7;
          end
          else begin
            first_byte <= 1'b1; // Next byte received is the register pointer
            state      <= ST_WR_BYTE;
            bit_idx    <= 3'd7;
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
        if (first_byte) begin
          // First byte after Slave Address + Write is always the register pointer
          reg_ptr    <= shift_in;
          first_byte <= 1'b0;
        end
        else begin
          // Every following byte is stored into memory, pointer auto-increments
          memory[reg_ptr] <= shift_in;
          reg_ptr         <= reg_ptr + 1'b1;
        end
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
          // Master NACKs - end of read burst
          state <= ST_IDLE;
        end
        else begin
          // Master ACKs - auto-increment pointer and load next byte
          reg_ptr       <= reg_ptr + 1'b1;
          cur_read_byte <= memory[reg_ptr + 1'b1];
          state         <= ST_RD_BYTE;
          bit_idx       <= 3'd7;
        end
      end

      default: state <= ST_IDLE;
    endcase
  end

  // Output drive configuration on SCL falling edge
  always @(negedge scl) begin
    case (state)
      ST_ADDR_ACK: sda_drive <= matched;
      ST_WR_ACK:   sda_drive <= matched;
      ST_RD_BYTE:  sda_drive <= !cur_read_byte[bit_idx];
      default:     sda_drive <= 1'b0;
    endcase
  end

endmodule