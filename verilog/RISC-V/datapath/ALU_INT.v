module ALU_INT #
(
    parameter DATA_WIDTH = 32
)
(
    input wire clk,
    input wire reset,
    input wire OP,

    output reg [DATA_WIDTH - 1 : 0] result
);
    parameter   ADD_OP = 4'b0000,
                MUL_OP = 4'b0001,
                DIV_OP = 4'b0010,
                ARGMAX_OP = 4'b0100,
                AVG_OP = 4'b1000; // parameter 들은 예시를 적어둔 것이므로 수정이 필요하다.
    
    /* FILL IN THE BELLOW */
                

endmodule
