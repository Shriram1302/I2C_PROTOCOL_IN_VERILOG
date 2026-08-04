module i2c_master(input clk,
                  input rst,
                  input start,
                  input rw,
                  input [6:0] slave_addr,
                  input [7:0] reg_addr,
                  input [7:0] tx_data,
                  inout sda,
                  inout sck,
                  output reg [7:0] rx_data, 
                  output reg done,
                  output reg ack_error);
  wire clk_4;
  wire start_done;
  wire rep_start_done;
  wire read_done;
  wire m_ack_done;
  wire m_nack_done;
  wire byte_done;
  wire ack_done;
  wire stop_done;
  wire ack_received;
  wire [7:0] rx_byte;
  
  reg [4:0]sts;
  reg start_en;
  reg rep_start_en;
  reg read_en;
  reg m_ack_en;
  reg m_nack_en;
  reg byte_en;
  reg ack_en;
  reg stop_en;
  reg [7:0] current_tx_byte;
  reg start_toggle;
  reg start_sync0, start_sync1, start_sync2;
  wire start_pulse_clk4 = start_sync1 ^ start_sync2;

  always @(posedge clk or negedge rst) begin
    if (!rst)
      start_toggle <= 0;
    else if (start)
      start_toggle <= ~start_toggle;
  end

  always @(posedge clk_4 or negedge rst) begin
    if (!rst) begin
      start_sync0 <= 0;
      start_sync1 <= 0;
      start_sync2 <= 0;
    end
    else begin
      start_sync0 <= start_toggle;
      start_sync1 <= start_sync0;
      start_sync2 <= start_sync1;
    end
  end

  clock_divider u_dclock (
    .clk(clk),
    .out_clk(clk_4)
  );
  
  start_i2c u_start (
    .stat_en(start_en),
    .clk(clk_4),
    .rst(rst),
    .sda(sda),
    .sck(sck),
    .done(start_done)
  );
  
  repeated_start u_rep_s(
    .stat_en(rep_start_en),
    .clk(clk_4),
    .rst(rst),
    .sda(sda),
    .sck(sck),
    .done(rep_start_done)
  );
  
  read_byte u_read(
    .stat_en(read_en),
    .clk(clk_4),
    .rst(rst),
    .rx_byte(rx_byte),
    .sda(sda),
    .sck(sck),
    .done(read_done)
  );
  
  send_byte u_byte (
    .stat_en(byte_en),
    .clk(clk_4),
    .rst(rst),
    .tx_byte(current_tx_byte),
    .sda(sda),
    .sck(sck),
    .done(byte_done)
  );
  
  ack u_ack (
    .stat_en(ack_en),
    .clk(clk_4),
    .rst(rst),
    .sda(sda),
    .ack(ack_received),
    .sck(sck),
    .done(ack_done)
  );
  
  master_ack u_mack(
    .clk(clk_4),
    .rst(rst),
    .stat_en(m_ack_en),
    .sda(sda),
    .sck(sck),
    .done(m_ack_done)
  );
  
  master_nack u_mnack(
    .clk(clk_4),
    .rst(rst),
    .stat_en(m_nack_en),
    .sda(sda),
    .sck(sck),
    .done(m_nack_done)
  );
  
  stop_i2c u_stop (
    .stat_en(stop_en),
    .clk(clk_4),
    .rst(rst),
    .sda(sda),
    .sck(sck),
    .done(stop_done)
  );
  
  localparam IDLE                = 5'd0;
  localparam START_M             = 5'd1;
  localparam LOAD_SLV_ADDR_W     = 5'd2;
  localparam SEND_SLV_ADDR_W     = 5'd3;
  localparam ACK_SLV_ADDR_W      = 5'd4;
  localparam LOAD_REG_ADDR       = 5'd5;
  localparam SEND_REG_ADDR       = 5'd6;
  localparam ACK_REG_ADDR        = 5'd7;
  localparam LOAD_TX_DATA        = 5'd8;
  localparam SEND_TX_DATA        = 5'd9;
  localparam ACK_TX_DATA         = 5'd10;
  localparam STOP_M              = 5'd11;
  localparam DONE_M              = 5'd12;
  localparam REP_START_M         = 5'd13;
  localparam LOAD_SLV_ADDR_R     = 5'd14;
  localparam SEND_SLV_ADDR_R     = 5'd15;
  localparam ACK_SLV_ADDR_R      = 5'd16;
  localparam READ_DATA           = 5'd17;
  localparam MASTER_NACK_M       = 5'd18;
  localparam MASTER_ACK_M        = 5'd19;

 
  wire hold_sck_low = (sts == LOAD_SLV_ADDR_W) ||
                      (sts == LOAD_REG_ADDR)   ||
                      (sts == LOAD_TX_DATA)    ||
                      (sts == LOAD_SLV_ADDR_R);

  reg hold_sck_d1, hold_sck_d2;
  always @(posedge clk_4 or negedge rst) begin
    if (!rst) begin
      hold_sck_d1 <= 0;
      hold_sck_d2 <= 0;
    end
    else begin
      hold_sck_d1 <= hold_sck_low;
      hold_sck_d2 <= hold_sck_d1;
    end
  end

  assign sck = (hold_sck_low || hold_sck_d1 || hold_sck_d2) ? 1'b0 : 1'bz;

  always @(posedge clk_4 or negedge rst)
    begin 
      if(!rst)begin 
        start_en<=0;
        byte_en<=0;
        ack_en<=0;
        stop_en<=0;
        rep_start_en<=0;
        read_en<=0;
        m_ack_en<=0;
        m_nack_en<=0;
        done<=0;
        sts<=0;
        rx_data <= 8'd0;
        current_tx_byte <= 8'd0;
        ack_error<=0;
        sts <= IDLE;
      end
      else begin 
        start_en     <= 0;
        byte_en      <= 0;
        ack_en       <= 0;
        stop_en      <= 0;
        rep_start_en <= 0;
        read_en      <= 0;
        m_ack_en     <= 0;
        m_nack_en    <= 0;
        case(sts)
          IDLE:begin
            byte_en      <= 0;
            ack_en       <= 0;
            stop_en      <= 0;
            rep_start_en <= 0;
            read_en      <= 0;
            m_ack_en     <= 0;
            m_nack_en    <= 0;
            ack_error    <= 0;
            done         <= 0;
            if(start_pulse_clk4)
              sts<=START_M;
          end
          START_M: begin 
            start_en   <= 1;
            if(start_done) begin
              start_en <= 0;
              sts      <= LOAD_SLV_ADDR_W;
            end
          end
          LOAD_SLV_ADDR_W: begin 
            current_tx_byte <= {slave_addr, 1'b0};
            sts             <= SEND_SLV_ADDR_W;
          end
          SEND_SLV_ADDR_W: begin
            byte_en   <= 1;
            if(byte_done)begin
              byte_en <= 0;
              sts     <= ACK_SLV_ADDR_W;
            end
          end
          ACK_SLV_ADDR_W: begin
            ack_en<=1;
            if(ack_done)begin
              ack_en<=0;
              if(ack_received)begin
                ack_error<=0;
                sts<=LOAD_REG_ADDR;
              end
              else begin
                ack_error<=1;
                sts<=STOP_M;
              end
            end
          end
          LOAD_REG_ADDR: begin 
            current_tx_byte <= reg_addr;
            sts <= SEND_REG_ADDR;
          end
          SEND_REG_ADDR: begin 
            byte_en   <= 1;
            if(byte_done)begin
              byte_en <= 0;
              sts     <= ACK_REG_ADDR;
            end
          end
          ACK_REG_ADDR: begin 
            ack_en<=1;
            if(ack_done)begin
              ack_en<=0;
              if(ack_received)begin
                ack_error<=0;
                sts<= (!rw)? LOAD_TX_DATA : REP_START_M;
              end
              else begin
                ack_error<=1;
                sts<=STOP_M;
              end
            end

          end
          LOAD_TX_DATA: begin 
            current_tx_byte <= tx_data;
            sts<=SEND_TX_DATA;
          end
          SEND_TX_DATA: begin
            byte_en   <= 1;
            if(byte_done)begin
              byte_en <= 0;
              sts     <= ACK_TX_DATA;
            end
          end
          ACK_TX_DATA: begin 
            ack_en<=1;
            if(ack_done)begin
              ack_en<=0;
              if(ack_received)begin
                ack_error<=0;
                sts<=STOP_M;
              end
              else begin
                ack_error<=1;
                sts<=STOP_M;
              end
            end
          end
          REP_START_M: begin 
            rep_start_en<=1;
            if(rep_start_done) begin
              rep_start_en<=0;
              sts<=LOAD_SLV_ADDR_R;
            end
          end
          LOAD_SLV_ADDR_R: begin 
            current_tx_byte <= {slave_addr, 1'b1};
            sts             <= SEND_SLV_ADDR_R;
          end
          SEND_SLV_ADDR_R: begin 
            byte_en   <= 1;
            if(byte_done)begin
              byte_en <= 0;
              sts     <= ACK_SLV_ADDR_R;
            end
          end
          ACK_SLV_ADDR_R: begin 
            ack_en<=1;
            if(ack_done)begin
              ack_en<=0;
              if(ack_received)begin
                ack_error<=0;
                sts<=READ_DATA;
              end
              else begin
                ack_error<=1;
                sts<=STOP_M;
              end
            end
          end
          READ_DATA: begin 
            read_en<=1;
            if(read_done)begin
              read_en<=0;
              rx_data<=rx_byte;
              sts <= MASTER_NACK_M;
            end
          end
          MASTER_NACK_M: begin 
             m_nack_en <= 1;
            if (m_nack_done) begin
              m_nack_en <= 0;
              sts <= STOP_M;
            end
          end
          MASTER_ACK_M: begin 
            m_ack_en <= 1;
            if (m_ack_done) begin
              m_ack_en <= 0;
              sts <= READ_DATA;
            end
          end
          STOP_M: begin
            stop_en<=1;
            if(stop_done)begin
              stop_en<=0;
              sts<=DONE_M;
            end
          end
          DONE_M: begin 
            done<=1;
            sts<=IDLE;
          end
          default: begin
                start_en <= 0;
                byte_en  <= 0;
                ack_en   <= 0;
                stop_en  <= 0;
                done     <= 0;
                ack_error<= 0;
                rep_start_en<=0;
                read_en<=0;
                m_ack_en<=0;
                m_nack_en<=0;
                sts      <= IDLE;
          end
        endcase
      end
    end
endmodule
