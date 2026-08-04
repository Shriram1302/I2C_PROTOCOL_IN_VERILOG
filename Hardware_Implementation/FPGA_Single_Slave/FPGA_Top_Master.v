
module fpga_master_top (
    input        clk,  
    input        start,      
    input        btn_rst,   
    inout        sck,       
    inout        sda,        
    output       done,       
    output       ack_error,  
    output [7:0] rx_data     
);


    wire rst_n = ~btn_rst;


    localparam [6:0] TARGET_SLAVE_ADDR = 7'h3C; 
    localparam [7:0] TARGET_REG_ADDR   = 8'h00; 


    reg         start_pulse;
    wire        master_done;
    wire        master_ack_err;
    wire [7:0]  master_rx_byte;


    //reg [23:0] timer;

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            timer       <= 24'd0;
//            start_pulse <= 1'b0;
//        end else begin
//            if (timer == 24'd10_000_000) begin 
//                timer       <= 24'd0;
//                start_pulse <= 1'b1;           
//            end else begin
//                timer       <= timer + 1'b1;
//                start_pulse <= 1'b0;
//            end
//        end
//    end


    reg done_led_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_led_reg <= 1'b0;
        end else if (master_done) begin
            done_led_reg <= ~done_led_reg; 
        end
    end

    reg ack_err_led_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack_err_led_reg <= 1'b0;
        end else if (master_ack_err) begin
            ack_err_led_reg <= 1'b1;
        end
    end


    assign done      = done_led_reg;     
    assign ack_error = ack_err_led_reg;   
    assign rx_data   = master_rx_byte;

    i2c_master u_i2c_master (
        .clk        (clk),
        .rst        (rst_n),              
        .start      (start),        
        .rw         (1'b1),              
        .slave_addr (TARGET_SLAVE_ADDR),  
        .reg_addr   (TARGET_REG_ADDR),    
        .tx_data    (8'h00),              
        .sda        (sda),
        .sck        (sck),
        .rx_data    (master_rx_byte),     
        .done       (master_done),        
        .ack_error  (master_ack_err)      
    );

endmodule