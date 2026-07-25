`timescale 1ns/1ps

module i2c_master_tb;

    reg clk;
    reg reset;
    reg start_p;
    reg read_write;
    reg [6:0] dev_addr;
    reg [7:0] write_data;

    wire [7:0] read_data;
    wire busy_flag;
    wire done_flag;
    wire error_ack;
    wire sda_pin;
    wire scl_pin;

    assign sda_pin = (sda_pin === 1'bz) ? 1'b0 : 1'bz;

    i2c_master #(
        .SYS_CLK_FREQ(50000000),
        .BUS_CLK_FREQ(100000)
    ) uut (
        .clk(clk),
        .reset(reset),
        .start_p(start_p),
        .read_write(read_write),
        .dev_addr(dev_addr),
        .write_data(write_data),
        .read_data(read_data),
        .busy_flag(busy_flag),
        .done_flag(done_flag),
        .error_ack(error_ack),
        .sda_pin(sda_pin),
        .scl_pin(scl_pin)
    );

    // 50 MHz clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Main stimulus
    initial begin
        reset      = 1;
        start_p    = 0;
        read_write = 0;
        dev_addr   = 7'h50;
        write_data = 8'hA5;

        #100;
        reset = 0;

        #100;
        start_p = 1;
        #20;
        start_p = 0;

        wait(done_flag);
        #100;

        $display("ACK Error Flag = %b", error_ack);
        $display("Received Data  = %h", read_data);

        #100;
        $finish;
    end

    // Bus monitoring
    initial begin
        $monitor("Time=%0t | Busy=%b | Done=%b | SDA=%b | SCL=%b | ACK_ERR=%b",
                 $time, busy_flag, done_flag, sda_pin, scl_pin, error_ack);
    end

endmodule