module Icache #
(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NONE_INST = 0
)
(
    input wire clk,
    input wire reset,
    input wire [ADDR_WIDTH - 1 : 0] PC_in,

    output reg [ADDR_WIDTH - 1 :0] INST_out
);
    reg [DATA_WIDTH - 1 : 0] mem [ADDR_WIDTH - 1 : 0];
    /*
        INSERT SDRAM(mem) GENERATION CODE
    */
    always @(*) begin
        if(reset) begin
            INST_out = NONE_INST;
        end
        else begin
            INST_out = mem[PC_in];
        end
    end

endmodule

