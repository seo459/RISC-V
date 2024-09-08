module PC #
(
    parameter ADDR_WIDTH = 32
)
(
    input wire clk,
    input wire sel,
    
    input wire [ADDR_WIDTH -1 : 0] PC_pc4,
    input wire [ADDR_WIDTH -1 : 0] PC_jump,
    
    output reg [ADDR_WIDTH -1 : 0] PC_out
);
    always @(*) begin
        if(sel == 1'b1) begin
            PC_out = PC_jump;
        end
        else begin
            PC_out = PC_pc4; // PC_pc4 = current_PC + 4;
        end
    end
endmodule
