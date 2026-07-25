`timescale 1ns/1ps

module i2c_master
#(
    parameter SYS_CLK_FREQ  = 50000000,
    parameter BUS_CLK_FREQ  = 100000
)
(
    input  wire       clk,
    input  wire       reset,
    input  wire       start_p,
    input  wire       read_write,
    input  wire [6:0] dev_addr,
    input  wire [7:0] write_data,
    output reg  [7:0] read_data,
    output reg        busy_flag,
    output reg        done_flag,
    output reg        error_ack,
    inout  wire       sda_pin,
    output wire       scl_pin
);

    // Clock division for I2C clock generation
    localparam CLK_DIV = SYS_CLK_FREQ / (BUS_CLK_FREQ * 4);

    reg [15:0] tick_count;
    reg        scl_reg;

    assign scl_pin = busy_flag ? scl_reg : 1'b1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tick_count <= 0;
            scl_reg    <= 1;
        end else begin
            if (tick_count == CLK_DIV - 1) begin
                tick_count <= 0;
                scl_reg    <= ~scl_reg;
            end else begin
                tick_count <= tick_count + 1;
            end
        end
    end

    // Tri-state SDA driver
    reg sda_out_en;
    reg sda_out_reg;

    assign sda_pin = sda_out_en ? sda_out_reg : 1'bz;
    wire sda_in_wire = sda_pin;

    // FSM State Encoding
    localparam S_IDLE       = 0;
    localparam S_START      = 1;
    localparam S_SEND_ADDR  = 2;
    localparam S_WAIT_ACK1  = 3;
    localparam S_WRITE      = 4;
    localparam S_WAIT_ACK2  = 5;
    localparam S_READ       = 6;
    localparam S_SEND_NACK  = 7;
    localparam S_STOP       = 8;
    localparam S_END        = 9;

    reg [3:0] state_reg;
    reg [7:0] data_buffer;
    reg [2:0] bit_idx;

    // Main controller FSM
    always @(posedge scl_reg or posedge reset) begin
        if (reset) begin
            state_reg   <= S_IDLE;
            busy_flag   <= 0;
            done_flag   <= 0;
            error_ack   <= 0;
            sda_out_en  <= 1;
            sda_out_reg <= 1;
            read_data   <= 0;
            data_buffer <= 0;
            bit_idx     <= 0;
        end else begin
            done_flag <= 0;

            case (state_reg)
                S_IDLE: begin
                    busy_flag   <= 0;
                    sda_out_en  <= 1;
                    sda_out_reg <= 1;
                    if (start_p) begin
                        busy_flag <= 1;
                        error_ack <= 0;
                        state_reg <= S_START;
                    end
                end

                S_START: begin
                    sda_out_reg <= 0;
                    data_buffer <= {dev_addr, read_write};
                    bit_idx     <= 7;
                    state_reg   <= S_SEND_ADDR;
                end

                S_SEND_ADDR: begin
                    sda_out_en  <= 1;
                    sda_out_reg <= data_buffer[bit_idx];
                    if (bit_idx == 0)
                        state_reg <= S_WAIT_ACK1;
                    else
                        bit_idx <= bit_idx - 1;
                end

                S_WAIT_ACK1: begin
                    sda_out_en <= 0;
                    if (sda_in_wire)
                        error_ack <= 1;

                    bit_idx <= 7;
                    if (~read_write) begin
                        data_buffer <= write_data;
                        state_reg   <= S_WRITE;
                    end else begin
                        read_data <= 0;
                        state_reg <= S_READ;
                    end
                end

                S_WRITE: begin
                    sda_out_en  <= 1;
                    sda_out_reg <= data_buffer[bit_idx];
                    if (bit_idx == 0)
                        state_reg <= S_WAIT_ACK2;
                    else
                        bit_idx <= bit_idx - 1;
                end

                S_WAIT_ACK2: begin
                    sda_out_en <= 0;
                    if (sda_in_wire)
                        error_ack <= 1;
                    state_reg <= S_STOP;
                end


                S_READ: begin
                    sda_out_en          <= 0;
                    read_data[bit_idx]  <= sda_in_wire;
                    if (bit_idx == 0)
                        state_reg <= S_SEND_NACK;
                    else
                        bit_idx <= bit_idx - 1;
                end


                S_SEND_NACK: begin
                    sda_out_en  <= 1;
                    sda_out_reg <= 1;
                    state_reg   <= S_STOP;
                end

                S_STOP: begin
                    sda_out_en  <= 1;
                    sda_out_reg <= 0;
                    state_reg   <= S_END;
                end

                
                S_END: begin
                    sda_out_reg <= 1;
                    busy_flag   <= 0;
                    done_flag   <= 1;
                    state_reg   <= S_IDLE;
                end

                default: state_reg <= S_IDLE;
            endcase
        end
    end

endmodule