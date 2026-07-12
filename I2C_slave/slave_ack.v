module slave_ack(
    input clk,
    input rst,
    input stat_en,
    input sck,
    output sda_out,
    output sda_oe,
    output reg done
);

    reg [2:0] sts;
    reg sda_d_low;
    reg sck_prev;

    localparam IDLE         = 3'd0;
    localparam SDA_LOW      = 3'd1;
    localparam WAIT_SCL_H   = 3'd2;
    localparam WAIT_SCL_L   = 3'd3;
    localparam DONE         = 3'd4;
    localparam WAIT_EN_LOW  = 3'd5;

    assign sda_out = 1'b0;
    assign sda_oe  = sda_d_low;

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            sts       <= IDLE;
            sda_d_low <= 1'b0;
            sck_prev  <= 1'b0;
            done      <= 1'b0;
        end
        else begin
            done     <= 1'b0;
            sck_prev <= sck;
            
            if (!stat_en && sts != WAIT_EN_LOW) begin
                sts       <= IDLE;
                sda_d_low <= 1'b0;
            end
            else begin
                case (sts)
                    IDLE: begin
                        sda_d_low <= 1'b0;
                        if(stat_en)
                            sts <= SDA_LOW;
                    end
                    SDA_LOW: begin
                        sda_d_low <= 1'b1;
                        if(!sck_prev && sck) // Wait for SCK rising edge
                            sts <= WAIT_SCL_H;
                    end
                    WAIT_SCL_H: begin
                        if(sck_prev && !sck) // Wait for SCK falling edge
                            sts <= WAIT_SCL_L;
                    end
                    WAIT_SCL_L: begin
                        sts <= DONE;
                    end
                    DONE: begin
                        sda_d_low <= 1'b0;
                        done      <= 1'b1;
                        sts       <= WAIT_EN_LOW;
                    end
                    WAIT_EN_LOW: begin
                        if(!stat_en)
                            sts <= IDLE;
                    end
                    default: sts <= IDLE;
                endcase
            end
        end
    end
endmodule