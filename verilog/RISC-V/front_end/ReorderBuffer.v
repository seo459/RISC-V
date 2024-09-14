// =========================================
// Reorder Buffer Module for Out-of-Order Processor
// =========================================

module ReorderBuffer(
    input clk,
    input reset,

    // Inputs from Decode & Rename
    input [31:0] rob_pc_in [0:3],
    input [31:0] rob_inst_in [0:3],
    input [5:0] rob_src1_phy_reg_in [0:3],
    input [5:0] rob_src2_phy_reg_in [0:3],
    input [5:0] rob_dst_phy_reg_in [0:3],
    input [4:0] rob_dst_arch_reg_in [0:3],
    input [5:0] rob_old_dst_phy_reg_in [0:3],
    input [3:0] rob_valid_in, // Indicates which entries are valid

    // Inputs from Execution units (instruction completion)
    input [5:0] exec_dst_phy_reg_in [0:3],
    input [31:0] exec_result_in [0:3],
    input [3:0] exec_valid_in, // Indicates which entries are valid

    // Outputs for instruction commit
    output reg [5:0] commit_dst_phy_reg_out [0:3],
    output reg [4:0] commit_dst_arch_reg_out [0:3],
    output reg [31:0] commit_result_out [0:3],
    output reg [3:0] commit_valid_out,

    // Control signals
    input mispredict, // Branch misprediction signal
    input flush,      // Flush signal

    // Outputs to Free List (to free physical registers)
    output reg [5:0] free_phy_regs_out [0:3],
    output reg [3:0] free_phy_regs_valid_out,

    // Outputs to update the committed register map
    output reg [5:0] committed_reg_map_out [0:31]
);

    parameter ROB_SIZE = 64;
    integer i;

    // Reorder Buffer entries
    reg [31:0] rob_pc [0:ROB_SIZE-1];
    reg [31:0] rob_inst [0:ROB_SIZE-1];
    reg [5:0] rob_src1_phy_reg [0:ROB_SIZE-1];
    reg [5:0] rob_src2_phy_reg [0:ROB_SIZE-1];
    reg [5:0] rob_dst_phy_reg [0:ROB_SIZE-1];
    reg [4:0] rob_dst_arch_reg [0:ROB_SIZE-1];
    reg [5:0] rob_old_dst_phy_reg [0:ROB_SIZE-1];
    reg rob_valid [0:ROB_SIZE-1];
    reg rob_ready [0:ROB_SIZE-1];
    reg [31:0] rob_result [0:ROB_SIZE-1];

    // Head and tail pointers
    reg [5:0] rob_head;
    reg [5:0] rob_tail;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rob_head <= 0;
            rob_tail <= 0;
            for (i = 0; i < ROB_SIZE; i = i + 1) begin
                rob_valid[i] <= 0;
                rob_ready[i] <= 0;
                rob_pc[i] <= 32'b0;
                rob_inst[i] <= 32'b0;
                rob_src1_phy_reg[i] <= 6'b0;
                rob_src2_phy_reg[i] <= 6'b0;
                rob_dst_phy_reg[i] <= 6'b0;
                rob_dst_arch_reg[i] <= 5'b0;
                rob_old_dst_phy_reg[i] <= 6'b0;
                rob_result[i] <= 32'b0;
            end
            for (i = 0; i < 32; i = i + 1) begin
                committed_reg_map_out[i] <= 6'b0;
            end
        end else if (flush || mispredict) begin
            // Flush the ROB
            rob_head <= 0;
            rob_tail <= 0;
            for (i = 0; i < ROB_SIZE; i = i + 1) begin
                rob_valid[i] <= 0;
                rob_ready[i] <= 0;
            end
        end else begin
            // Add new entries from Decode & Rename
            for (i = 0; i < 4; i = i + 1) begin
                if (rob_valid_in[i]) begin
                    if (((rob_tail + 1) % ROB_SIZE) != rob_head) begin
                        rob_pc[rob_tail] <= rob_pc_in[i];
                        rob_inst[rob_tail] <= rob_inst_in[i];
                        rob_src1_phy_reg[rob_tail] <= rob_src1_phy_reg_in[i];
                        rob_src2_phy_reg[rob_tail] <= rob_src2_phy_reg_in[i];
                        rob_dst_phy_reg[rob_tail] <= rob_dst_phy_reg_in[i];
                        rob_dst_arch_reg[rob_tail] <= rob_dst_arch_reg_in[i];
                        rob_old_dst_phy_reg[rob_tail] <= rob_old_dst_phy_reg_in[i];
                        rob_valid[rob_tail] <= 1;
                        rob_ready[rob_tail] <= 0;
                        rob_result[rob_tail] <= 32'b0;

                        rob_tail <= (rob_tail + 1) % ROB_SIZE;
                    end
                end
            end

            // Update ROB entries with execution results
            for (i = 0; i < 4; i = i + 1) begin
                if (exec_valid_in[i]) begin
                    integer j;
                    for (j = 0; j < ROB_SIZE; j = j + 1) begin
                        if (rob_valid[j] && !rob_ready[j] && (rob_dst_phy_reg[j] == exec_dst_phy_reg_in[i])) begin
                            rob_ready[j] <= 1;
                            rob_result[j] <= exec_result_in[i];
                            break;
                        end
                    end
                end
            end

            // Commit instructions in order
            integer commit_count;
            commit_count = 0;
            while (rob_valid[rob_head] && rob_ready[rob_head] && (commit_count < 4)) begin
                // Commit the instruction
                commit_dst_phy_reg_out[commit_count] <= rob_dst_phy_reg[rob_head];
                commit_dst_arch_reg_out[commit_count] <= rob_dst_arch_reg[rob_head];
                commit_result_out[commit_count] <= rob_result[rob_head];
                commit_valid_out[commit_count] <= 1'b1;

                // Update the committed register map
                committed_reg_map_out[rob_dst_arch_reg[rob_head]] <= rob_dst_phy_reg[rob_head];

                // Free the old physical register
                free_phy_regs_out[commit_count] <= rob_old_dst_phy_reg[rob_head];
                free_phy_regs_valid_out[commit_count] <= (rob_old_dst_phy_reg[rob_head] != 0);

                // Clear the ROB entry
                rob_valid[rob_head] <= 0;
                rob_ready[rob_head] <= 0;

                // Advance the head pointer
                rob_head <= (rob_head + 1) % ROB_SIZE;

                commit_count = commit_count + 1;
            end

            // Zero out remaining commit outputs if less than 4 instructions committed
            for (i = commit_count; i < 4; i = i + 1) begin
                commit_valid_out[i] <= 1'b0;
                free_phy_regs_valid_out[i] <= 1'b0;
            end
        end
    end

endmodule
