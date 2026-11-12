// Parameterized Synchronous FIFO
`timescale 1ns/1ps
module sync_fifo #(
    parameter DATA_WIDTH = 8,                 // width of each data word
    parameter DEPTH      = 16,                // number of locations
    parameter ADDR_WIDTH = 4                  // log2(DEPTH)
)(
    input  wire                  clk,         // system clock
    input  wire                  rst_n,       // active-low reset
    input  wire                  wr_en,       // write request
    input  wire                  rd_en,       // read request
    input  wire [DATA_WIDTH-1:0] din,         // write data
    output reg  [DATA_WIDTH-1:0] dout,        // read data
    output wire                  full,        // FIFO full flag
    output wire                  empty,       // FIFO empty flag
    output reg                   overflow,    // write tried when full
    output reg                   underflow,   // read tried when empty
    output wire [ADDR_WIDTH:0]   data_count   // words stored
);

    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers with one extra MSB (wrap bit)
    reg [ADDR_WIDTH:0] wr_ptr;
    reg [ADDR_WIDTH:0] rd_ptr;

    wire wr_ok = wr_en && !full;     // valid write
    wire rd_ok = rd_en && !empty;    // valid read

    // Write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_ptr <= 0;
        else if (wr_ok) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    // Read logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            dout   <= 0;
        end else if (rd_ok) begin
            dout   <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    // Error flags (one-cycle pulse)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            overflow  <= wr_en && full;
            underflow <= rd_en && empty;
        end
    end

    // Status flags
    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                   (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]);
    assign data_count = wr_ptr - rd_ptr;

endmodule
