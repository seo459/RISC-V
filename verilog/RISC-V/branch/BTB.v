module BTB #
(
    parameter ADDR_WIDTH = 32,
    parameter OFFSET_WIDTH = 4,
    parameter INDEX_WIDTH = 3,
    parameter TAG_WIDTH = BRANCH_PC - (OFFSET_WIDTH + INDEX_WIDTH),
    parameter BRANCH_PC  = 10 // 2^10 = 1024개를 참조할 수 있음. Branch Target Buffer(BTB) 를 이용하여 branch condition, target addr 계산을 생략함.
)
(
    input wire clk,
    input wire [BRANCH_PC - 1 : 0] PC_in,
    
    output wire [ADDR_WIDTH - 1 : 0] PC_out // branch target address
);
    // 2-way associative BTB cache structure.
    assign [BRANCH_PC - 1 : BRANCH_PC - TAG_WIDTH] aa;
endmodule
