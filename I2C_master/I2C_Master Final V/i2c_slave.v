module i2c_slave_model
#(
    parameter        SLAVE_ADDR = 7'h3C,
    parameter [7:0]  READ_DATA0 = 8'h00,   // byte returned on the 1st read from this slave
    parameter [7:0]  READ_DATA1 = 8'h00    // byte returned on the 2nd (and later) read
)
(
    input  scl,
    inout  sda
);

  // ------------------------------------------------------------------
  // Bus drive - open-drain: only ever pull low or release to 'z'
  // ------------------------------------------------------------------
  reg sda_drive;
  assign sda = sda_drive ? 1'b0 : 1'bz;

  // ------------------------------------------------------------------
  // FSM state
  // ------------------------------------------------------------------
  localparam ST_IDLE     = 3'd0;
  localparam ST_ADDR     = 3'd1; // shifting in 7 addr bits + R/W
  localparam ST_ADDR_ACK = 3'd2; // ack slot for the address byte
  localparam ST_WR_BYTE  = 3'd3; // shifting in a byte written by master
  localparam ST_WR_ACK   = 3'd4; // ack slot for a written byte
  localparam ST_RD_BYTE  = 3'd5; // shifting out a data byte to master
  localparam ST_RD_ACK   = 3'd6; // master's ack/nack slot for a read byte

  reg [2:0] state;
  reg [2:0] bit_idx;      // counts 7 downto 0, MSB first
  reg [7:0] shift_in;      // incoming address/write-data bits
  reg [7:0] cur_read_byte; // byte currently being shifted out
  reg       is_read;       // R/W bit latched from the address byte
  reg       matched;       // did the address byte match SLAVE_ADDR
  reg       read_idx;      // which data byte to send on the *next* read

  initial begin
    state         = ST_IDLE;
    bit_idx       = 3'd7;
    shift_in      = 8'h00;
    cur_read_byte = 8'h00;
    is_read       = 1'b0;
    matched       = 1'b0;
    read_idx      = 1'b0;
    sda_drive     = 1'b0;
  end

  // ------------------------------------------------------------------
  // START / STOP detection.
  // I2C data only changes while SCL is low, so a transition on SDA
  // while SCL is high is always a START or STOP, never a data bit.
  // These fire asynchronously and simply (re)point the FSM at the
  // address phase or back to idle; they never touch sda_drive so
  // there's no multiple-driver conflict with the negedge-scl block
  // below, which is the sole driver of sda_drive.
  // ------------------------------------------------------------------
  always @(negedge sda) begin
    if (scl) begin
      // START or repeated START
      state   <= ST_ADDR;
      bit_idx <= 3'd7;
    end
  end

  always @(posedge sda) begin
    if (scl) begin
      // STOP
      state <= ST_IDLE;
    end
  end

  // ------------------------------------------------------------------
  // Sampling incoming bits / advancing the FSM - on posedge scl the
  // bit on sda is valid and stable.
  // ------------------------------------------------------------------
  always @(posedge scl) begin
    case (state)
      ST_ADDR: begin
        shift_in <= {shift_in[6:0], sda};
        if (bit_idx == 0) begin
          // shift_in[6:0] still holds the 7 address bits from the
          // previous 7 edges (non-blocking assignment ordering);
          // 'sda' right now is the R/W bit, the 8th bit of the byte.
          is_read <= sda;
          matched <= (shift_in[6:0] == SLAVE_ADDR);
          state   <= ST_ADDR_ACK;
          if (shift_in[6:0] == SLAVE_ADDR)
            $display("[%0t] Slave %h: address matched (%s)", $time,
                      SLAVE_ADDR, sda ? "READ" : "WRITE");
        end
        else
          bit_idx <= bit_idx - 1'b1;
      end

      ST_ADDR_ACK: begin
        // this edge is the address ack/nack bit itself
        if (matched) begin
          if (is_read) begin
            cur_read_byte <= read_idx ? READ_DATA1 : READ_DATA0;
            state   <= ST_RD_BYTE;
            bit_idx <= 3'd7;
          end
          else begin
            state   <= ST_WR_BYTE;
            bit_idx <= 3'd7;
          end
        end
        else
          state <= ST_IDLE; // not addressed - ignore rest of transaction
      end

      ST_WR_BYTE: begin
        shift_in <= {shift_in[6:0], sda};
        if (bit_idx == 0) begin
          $display("[%0t] Slave %h: received byte %h", $time, SLAVE_ADDR,
                    {shift_in[6:0], sda});
          state <= ST_WR_ACK;
        end
        else
          bit_idx <= bit_idx - 1'b1;
      end

      ST_WR_ACK: begin
        // loop back in case another byte follows (e.g. reg_addr then
        // tx_data); if a STOP/START happens instead, the async blocks
        // above override 'state' before it matters
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
          // NACK - master is done reading
          $display("[%0t] Slave %h: master NACKed, read complete", $time, SLAVE_ADDR);
          read_idx <= read_idx + 1'b1;
          state    <= ST_IDLE;
        end
        else begin
          // ACK - master wants another byte (not used by single-byte
          // reads, but supported for completeness)
          $display("[%0t] Slave %h: master ACKed, sending next byte", $time, SLAVE_ADDR);
          state   <= ST_RD_BYTE;
          bit_idx <= 3'd7;
        end
      end

      default: state <= ST_IDLE;
    endcase
  end

  // ------------------------------------------------------------------
  // Driving our own bits - decided on negedge scl so the new value is
  // stable well before the master's next posedge samples it. This is
  // the ONLY block that writes sda_drive.
  // ------------------------------------------------------------------
  always @(negedge scl) begin
    case (state)
      ST_ADDR_ACK: sda_drive <= matched;          // ACK only if addressed
      ST_WR_ACK:   sda_drive <= matched;          // ACK every written byte
      ST_RD_BYTE:  sda_drive <= !cur_read_byte[bit_idx];
      default:     sda_drive <= 1'b0;             // release in all other states
    endcase
  end

endmodule