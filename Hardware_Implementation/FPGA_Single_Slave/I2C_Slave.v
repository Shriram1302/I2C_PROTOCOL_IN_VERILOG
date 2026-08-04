module i2c_slave_model #(
    parameter [6:0] SLAVE_ADDR = 7'h3C
)(
    input        clk,          
    input        rst_n,        
    input        scl,          
    inout        sda,          
    input  [7:0] sensor_data,  
    output [7:0] display_data  
);


    reg [2:0] scl_sync, sda_sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], scl};
            sda_sync <= {sda_sync[1:0], sda};
        end
    end

    wire scl_curr = scl_sync[1];
    wire sda_curr = sda_sync[1];
    wire scl_prev = scl_sync[2];
    wire sda_prev = sda_sync[2];


    wire scl_pos    = (scl_curr == 1'b1) && (scl_prev == 1'b0);
    wire scl_neg    = (scl_curr == 1'b0) && (scl_prev == 1'b1);
    wire start_cond = (scl_curr == 1'b1) && (sda_prev == 1'b1) && (sda_curr == 1'b0);
    wire stop_cond  = (scl_curr == 1'b1) && (sda_prev == 1'b0) && (sda_curr == 1'b1);

    // FSM States
    localparam ST_IDLE     = 3'd0,
               ST_ADDR     = 3'd1,
               ST_ADDR_ACK = 3'd2,
               ST_WR_BYTE  = 3'd3,
               ST_WR_ACK   = 3'd4,
               ST_RD_BYTE  = 3'd5,
               ST_RD_ACK   = 3'd6;

    reg [2:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [7:0] display_reg;
    reg       sda_out;
    reg       is_read;
    reg       addr_match;

    assign display_data = display_reg;
    assign sda = sda_out ? 1'b0 : 1'bz; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            bit_cnt     <= 3'd7;
            shift_reg   <= 8'h00;
            display_reg <= 8'h00;
            sda_out     <= 1'b0;
            is_read     <= 1'b0;
            addr_match  <= 1'b0;
        end else begin
            if (start_cond) begin
                state      <= ST_ADDR;
                bit_cnt    <= 3'd7;
                sda_out    <= 1'b0;
                addr_match <= 1'b0;
            end else if (stop_cond) begin
                state   <= ST_IDLE;
                sda_out <= 1'b0;
            end else begin
                case (state)
                    ST_IDLE: begin
                        sda_out <= 1'b0;
                    end

                    ST_ADDR: begin
                        if (scl_pos) begin
                            shift_reg <= {shift_reg[6:0], sda_curr};
                            if (bit_cnt == 0) begin
                                is_read    <= sda_curr;
                                addr_match <= (shift_reg[6:0] == SLAVE_ADDR);
                                state      <= ST_ADDR_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    ST_ADDR_ACK: begin
                        if (scl_neg) begin
                            if (addr_match) begin
                                sda_out <= 1'b1; 
                            end else begin
                                state <= ST_IDLE;
                            end
                        end else if (scl_pos && addr_match) begin
                            bit_cnt <= 3'd7;
                            if (is_read) begin
                                shift_reg <= sensor_data; 
                                state     <= ST_RD_BYTE;
                            end else begin
                                state     <= ST_WR_BYTE;
                            end
                        end
                    end

                    ST_WR_BYTE: begin
                        if (scl_neg) begin
                            sda_out <= 1'b0; 
                        end else if (scl_pos) begin
                            shift_reg <= {shift_reg[6:0], sda_curr};
                            if (bit_cnt == 0) begin
                                display_reg <= {shift_reg[6:0], sda_curr};
                                state       <= ST_WR_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    ST_WR_ACK: begin
                        if (scl_neg) begin
                            sda_out <= 1'b1; 
                        end else if (scl_pos) begin
                            bit_cnt <= 3'd7;
                            state   <= ST_WR_BYTE;
                        end
                    end

                    ST_RD_BYTE: begin
                        if (scl_neg) begin
                            sda_out <= !shift_reg[bit_cnt];
                        end else if (scl_pos) begin
                            if (bit_cnt == 0) begin
                                state <= ST_RD_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    ST_RD_ACK: begin
                        if (scl_neg) begin
                            sda_out <= 1'b0; 
                        end else if (scl_pos) begin
                            if (sda_curr == 1'b1) begin 
                                state <= ST_IDLE;
                            end else begin 
                                shift_reg <= sensor_data;
                                bit_cnt   <= 3'd7;
                                state     <= ST_RD_BYTE;
                            end
                        end
                    end

                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule