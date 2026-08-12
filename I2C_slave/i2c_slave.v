module i2c_slave #(
    parameter SLAVE_ADDR = 7'h50
)(
    input clk,
    input rst,
    inout sda,
    input sck
);
  
  reg [7:0] mem [0:255];
  reg [7:0] register_pointer;
  reg [7:0] tx_byte;
  wire [7:0] rx_byte;

  reg slave_ack_en;
  reg slave_recv_byte_en;
  reg slave_send_byte_en;
  
  wire start_detect;
  wire stop_detect;
  wire ack_done;
  wire recv_done;
  wire send_done;
  
  wire sda_out_ack;
  wire sda_oe_ack;
  wire sda_out_send;
  wire sda_oe_send;
  
  reg rw;
  reg [4:0] sts;
  reg sck_prev;
  reg master_ack;
  reg repeated_start;
  
  
  assign sda = (slave_ack_en && sda_oe_ack)     ? sda_out_ack :
               (slave_send_byte_en && sda_oe_send) ? sda_out_send : 1'bz;
  
  slave_start_stop_detect u_start_stop (
    .clk(clk),
    .rst(rst),
    .sck(sck),
    .sda(sda),
    .start_detect(start_detect),
    .stop_detect(stop_detect)
  );
  
  slave_receive_byte u_receive (
    .stat_en(slave_recv_byte_en),
    .clk(clk),
    .rst(rst),
    .sda(sda),
    .sck(sck),
    .rx_byte(rx_byte),
    .done(recv_done)
  );
  
  slave_ack u_ack (
    .stat_en(slave_ack_en),
    .clk(clk),
    .rst(rst),
    .sck(sck),
    .sda_out(sda_out_ack),
    .sda_oe(sda_oe_ack),
    .done(ack_done)
  );
  
  slave_send_byte u_send (
    .stat_en(slave_send_byte_en),
    .clk(clk),
    .rst(rst),
    .tx_byte(tx_byte),
    .sda_out(sda_out_send),
    .sda_oe(sda_oe_send),
    .sck(sck),
    .done(send_done)
  );
  
  localparam IDLE              = 5'd0;
  localparam WAIT_ADDRESS      = 5'd1;
  localparam CHECK_ADDRESS     = 5'd2;
  localparam SEND_ACK1         = 5'd3;
  localparam RECEIVE_REGISTER  = 5'd4;
  localparam SEND_ACK2         = 5'd5;
  localparam RECEIVE_DATA      = 5'd6;
  localparam WRITE_MEMORY      = 5'd7;
  localparam SEND_ACK3         = 5'd8;
  localparam WAIT_REP_START    = 5'd9;
  localparam SEND_DATA         = 5'd10;
  localparam WAIT_MASTER_ACK   = 5'd11;
  localparam STOP_STATE        = 5'd12;
  
  always @(posedge clk or negedge rst) begin 
      if(!rst) begin 
        slave_ack_en       <= 0;
        slave_recv_byte_en <= 0;
        slave_send_byte_en <= 0;
        rw                 <= 0;
        register_pointer   <= 8'h00;
        tx_byte            <= 8'h00;
        sck_prev           <= 0;
        master_ack         <= 0;
        repeated_start     <= 0;
        sts                <= IDLE;
      end
      else begin
        sck_prev           <= sck;
        if (stop_detect) begin
          sts <= IDLE;
        end
        else if (start_detect && (sts != IDLE) && (sts != WAIT_ADDRESS)) begin
          repeated_start     <= 1;
          slave_ack_en       <= 0;
          slave_recv_byte_en <= 0;
          slave_send_byte_en <= 0;
          sts                <= WAIT_ADDRESS;
        end
        else begin
          case(sts)
            IDLE: begin
              repeated_start  <= 0;
              if(start_detect)
                sts <= WAIT_ADDRESS;
            end
            
            WAIT_ADDRESS: begin 
              slave_recv_byte_en   <= 1;
              if(recv_done) begin
                slave_recv_byte_en <= 0;
                sts                <= CHECK_ADDRESS;
              end
            end
            
            CHECK_ADDRESS: begin 
              rw <= rx_byte[0];
              if(rx_byte[7:1] == SLAVE_ADDR ) begin
                sts <= SEND_ACK1;
              end
              else begin
                sts <= IDLE;
              end
            end
            
            SEND_ACK1: begin
              slave_ack_en    <= 1;
              if(ack_done) begin
                slave_ack_en  <= 0;
                if(!rw) begin
                  sts <= RECEIVE_REGISTER;
                end
                else begin
                  tx_byte <= mem[register_pointer];
                  sts <= SEND_DATA;
                end
              end
            end
            
            RECEIVE_REGISTER: begin
              slave_recv_byte_en <= 1;
              if(recv_done) begin
                slave_recv_byte_en <= 0;
                register_pointer   <= rx_byte;
                sts                <= SEND_ACK2;
              end
            end
            
            SEND_ACK2: begin 
              slave_ack_en    <= 1;
              if(ack_done) begin
                slave_ack_en  <= 0;
                sts           <= RECEIVE_DATA;
              end
            end 
            
            RECEIVE_DATA: begin 
              slave_recv_byte_en <= 1;
              if(recv_done) begin
                slave_recv_byte_en <= 0;
                sts                <= WRITE_MEMORY;
              end
            end
            
            WRITE_MEMORY: begin
              mem [register_pointer] <= rx_byte;
              sts <= SEND_ACK3;
            end 
            
            SEND_ACK3: begin
              slave_ack_en    <= 1;
              if(ack_done) begin
                slave_ack_en  <= 0;
                sts           <= STOP_STATE;
              end
            end
            
            SEND_DATA: begin
              slave_send_byte_en <= 1;
              if(send_done) begin
                slave_send_byte_en <= 0;
                sts                <= WAIT_MASTER_ACK;
              end
            end
            
            WAIT_MASTER_ACK: begin
              if (!sck_prev && sck) begin
                master_ack <= ~sda;  
              end
              if (sck_prev && !sck) begin
                if (master_ack) begin
                  register_pointer <= register_pointer + 1;
                  tx_byte          <= mem[register_pointer + 1];
                  sts              <= SEND_DATA;
                end
                else begin
                  sts <= STOP_STATE;
                end
              end
            end
            
            STOP_STATE: begin
              if(stop_detect)
                sts <= IDLE;
            end
            
            default: sts <= IDLE;
          endcase
        end
      end
    end
endmodule
