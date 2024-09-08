module branch_context_2bc
(
    input wire clk,
    input wire reset,
    input wire taken_info,
    input wire valid_taken_info,

    output wire prediction
);

    parameter   SNT = 2'b00,
                WNT = 2'b01,
                WT  = 2'b10,
                ST  = 2'b11;

    parameter TAKEN     = 1'b1,
              NOT_TAKNE = 1'b0;

    reg [1:0] current_state;
    reg [1:0] next_state;

    assign prediction = ((current_state == WT) || (current_state == ST)) ? 1'b1 : 1'b0;

    always @(*) begin
        if(reset) begin
            next_state <= WNT;
        end

        else begin
            if(valid_taken_info) begin
                case (current_state)
                    SNT : begin
                        if(taken_info == TAKEN) 
                            next_state <= WNT;
                        else
                            next_state <= SNT;
                    end
                    WNT : begin
                        if(taken_info == TAKEN) 
                            next_state <= WT;
                        else
                            next_state <= SNT;
                    end
                    WT : begin
                        if(taken_info == TAKEN) 
                            next_state <= ST;
                        else
                            next_state <= WNT;
                    end
                    ST : begin
                        if(taken_info == TAKEN) 
                            next_state <= ST;
                        else
                            next_state <= WT;
                    end
                endcase
            end
            else begin
                next_state <= current_state;
            end
        end
    end

    always @(posedge clk) begin
        current_state <= next_state;
    end
endmodule
