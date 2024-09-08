module PE #(
    parameter DATA_WIDTH = 32
) (
    input clk,
    input reset,
    input wire [DATA_WIDTH-1 :0] weight_north, //coming input
    input wire [DATA_WIDTH-1 :0] activation_west,

    output wire [DATA_WIDTH-1 :0] weight_south, //passing output
    output wire [DATA_WIDTH-1 :0] activation_east,
    output wire [DATA_WIDTH-1 :0] result
);

    reg [DATA_WIDTH-1 :0] r_result;
    reg [DATA_WIDTH-1 :0] r_next_result;

    reg [DATA_WIDTH-1 :0] r_weight;
    reg [DATA_WIDTH-1 :0] r_activation;

    assign result          = r_result;
    assign weight_south    = r_weight;
    assign activation_east = r_activation; 

    always @(*) begin
        r_next_result <= r_result + (weight_north * activation_west);
    end

    always @(posedge clk or posedge reset) begin
       if(reset) begin
            r_result     <= 0;
            r_weight     <= 0;
            r_activation <= 0;
       end
       else begin
            r_result     <= r_next_result;
            r_weight     <= weight_north;
            r_activation <= activation_west;
       end
    end

endmodule
