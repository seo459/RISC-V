// ================================================
// Decode & Rename Module for Out-of-Order Processor
// ================================================

module DecodeRename(
    input clk,
    input reset,

    // Instruction fetch bundle (up to 4 instructions per cycle)
    input [31:0] inst_in [0:3],       // 32-bit instructions, array indices 0 to 3
    input [31:0] pc_in [0:3],         // Corresponding PCs for each instruction

    // Free physical register list
    input [5:0] free_phy_regs_in [0:15], // Free physical registers (indices), array indices 0 to 15
    // Explanation:
    // - There are a total of 64 physical registers (6 bits to index 0-63).
    // - The array size is [0:15] to hold up to 16 free physical registers.
    // - Although we process up to 4 instructions per cycle, we may need more free registers due to pipeline depth and to prevent stalling.

    input [3:0] free_phy_regs_valid,     // Number of valid free registers (0 to 16)
    // Explanation:
    // - Indicates how many entries in free_phy_regs_in are valid.
    // - The value ranges from 0 to 16.

    // Speculative register map (maps architectural to physical registers)
    input [5:0] spec_reg_map_in [0:31],  // 32 architectural registers mapping to physical registers
    // Explanation:
    // - Each architectural register (0-31) maps to a physical register (0-63).
    // - 6 bits are used to index 64 physical registers.

    // Outputs to Issue Queue or Reservation Stations
    output reg [31:0] renamed_inst_out [0:3], // Renamed instructions
    output reg [5:0] src1_phy_reg_out [0:3],  // Source physical registers
    output reg [5:0] src2_phy_reg_out [0:3],
    output reg [5:0] dst_phy_reg_out [0:3],   // Destination physical registers
    output reg [4:0] dst_arch_reg_out [0:3],  // Destination architectural registers

    // Outputs to Reorder Buffer
    output reg [31:0] rob_pc_out [0:3],
    output reg [31:0] rob_inst_out [0:3],
    output reg [5:0] rob_src1_phy_reg_out [0:3],
    output reg [5:0] rob_src2_phy_reg_out [0:3],
    output reg [5:0] rob_dst_phy_reg_out [0:3],
    output reg [4:0] rob_dst_arch_reg_out [0:3],
    output reg [5:0] rob_old_dst_phy_reg_out [0:3], // Old mapping for recovery

    // Updated speculative register map
    output reg [5:0] updated_spec_reg_map [0:31],

    // Allocated physical registers
    output reg [5:0] allocated_phy_regs_out [0:3],
    output reg [3:0] allocated_phy_regs_valid_out
);

    integer i; // Loop index variable

    // Internal variables
    reg [4:0] rs1_arch_reg [0:3];  // Source 1 architectural registers (5 bits to index 0-31)
    reg [4:0] rs2_arch_reg [0:3];  // Source 2 architectural registers
    reg [4:0] rd_arch_reg [0:3];   // Destination architectural registers
    reg [5:0] rs1_phy_reg [0:3];   // Source 1 physical registers
    reg [5:0] rs2_phy_reg [0:3];   // Source 2 physical registers
    reg [5:0] rd_phy_reg [0:3];    // Destination physical registers
    reg [31:0] inst [0:3];         // Local copy of instructions

    reg [5:0] spec_reg_map [0:31];       // Local copy of speculative register map, Mappings of architectural to physical registers.
    reg [5:0] new_spec_reg_map [0:31];   // Updated speculative register map

    // Free physical registers
    reg [5:0] free_phy_regs [0:15];      // Local array of free physical registers
    integer free_phy_reg_idx;            // Index to track allocation from free_phy_regs
    integer num_dest_regs;               // Number of destination registers in current instruction bundle

    always @(*) begin
        // Initialize free physical registers
        for (i = 0; i < 16; i = i + 1) begin
            if (i < free_phy_regs_valid)
                free_phy_regs[i] = free_phy_regs_in[i]; // Copy valid free physical registers
            else
                free_phy_regs[i] = 6'b0; // Zero out unused entries
        end
        free_phy_reg_idx = 0; // Reset index for allocation

        // Copy the speculative register map
        for (i = 0; i < 32; i = i + 1) begin
            spec_reg_map[i] = spec_reg_map_in[i];
            new_spec_reg_map[i] = spec_reg_map_in[i]; // ?
        end

        // Count the number of destination registers
        num_dest_regs = 0;
        for (i = 0; i < 4; i = i + 1) begin
            inst[i] = inst_in[i];
            rd_arch_reg[i] = inst[i][11:7]; // Extract destination architectural register (bits [11:7])
            if (rd_arch_reg[i] != 0)
                num_dest_regs = num_dest_regs + 1; // Increment if destination register is not x0
        end

        // Check for resource availability
        if (num_dest_regs > free_phy_regs_valid) begin
            // Not enough free physical registers, stall the pipeline
            // Zero out outputs to indicate stalling (NOP)
            for (i = 0; i < 4; i = i + 1) begin
                renamed_inst_out[i] = 32'b0;
                src1_phy_reg_out[i] = 6'b0;
                src2_phy_reg_out[i] = 6'b0;
                dst_phy_reg_out[i] = 6'b0;
                dst_arch_reg_out[i] = 5'b0;

                rob_pc_out[i] = 32'b0;
                rob_inst_out[i] = 32'b0;
                rob_src1_phy_reg_out[i] = 6'b0;
                rob_src2_phy_reg_out[i] = 6'b0;
                rob_dst_phy_reg_out[i] = 6'b0;
                rob_dst_arch_reg_out[i] = 5'b0;
                rob_old_dst_phy_reg_out[i] = 6'b0;

                allocated_phy_regs_out[i] = 6'b0;
                allocated_phy_regs_valid_out[i] = 1'b0;
            end
            // Keep the speculative register map unchanged
            for (i = 0; i < 32; i = i + 1) begin
                updated_spec_reg_map[i] = spec_reg_map_in[i];
            end
        end else begin
            // Proceed with renaming
            for (i = 0; i < 4; i = i + 1) begin
                inst[i] = inst_in[i];
                // Decode the instruction fields
                rs1_arch_reg[i] = inst[i][19:15]; // Source 1 architectural register (bits [19:15])
                rs2_arch_reg[i] = inst[i][24:20]; // Source 2 architectural register (bits [24:20])
                rd_arch_reg[i] = inst[i][11:7];   // Destination architectural register (bits [11:7])

                // Get the physical registers for source operands from speculative map
                rs1_phy_reg[i] = new_spec_reg_map[rs1_arch_reg[i]];
                rs2_phy_reg[i] = new_spec_reg_map[rs2_arch_reg[i]];

                // Allocate a new physical register for destination
                if (rd_arch_reg[i] != 0) begin
                    rd_phy_reg[i] = free_phy_regs[free_phy_reg_idx]; // Assign next free physical register
                    free_phy_reg_idx = free_phy_reg_idx + 1;         // Increment index

                    // Save old mapping for recovery
                    rob_old_dst_phy_reg_out[i] = new_spec_reg_map[rd_arch_reg[i]];

                    // Update speculative register map with new mapping
                    new_spec_reg_map[rd_arch_reg[i]] = rd_phy_reg[i];

                    allocated_phy_regs_out[i] = rd_phy_reg[i];
                    allocated_phy_regs_valid_out[i] = 1'b1;
                end else begin
                    // If destination register is x0, no allocation needed
                    rd_phy_reg[i] = 6'b0;
                    rob_old_dst_phy_reg_out[i] = 6'b0;
                    allocated_phy_regs_out[i] = 6'b0;
                    allocated_phy_regs_valid_out[i] = 1'b0;
                end

                // Prepare outputs for Issue Queue or Reservation Stations
                src1_phy_reg_out[i] = rs1_phy_reg[i];
                src2_phy_reg_out[i] = rs2_phy_reg[i];
                dst_phy_reg_out[i] = rd_phy_reg[i];
                dst_arch_reg_out[i] = rd_arch_reg[i];

                // Renamed instruction (custom format with physical registers)
                renamed_inst_out[i] = {inst[i][31:25], rd_phy_reg[i], inst[i][14:12], rs1_phy_reg[i], rs2_phy_reg[i], inst[i][6:0]};
                // Note: Instruction format may need adjustment based on ISA specifics.

                // Outputs to Reorder Buffer
                rob_pc_out[i] = pc_in[i];
                rob_inst_out[i] = inst[i];
                rob_src1_phy_reg_out[i] = rs1_phy_reg[i];
                rob_src2_phy_reg_out[i] = rs2_phy_reg[i];
                rob_dst_phy_reg_out[i] = rd_phy_reg[i];
                rob_dst_arch_reg_out[i] = rd_arch_reg[i];
            end

            // Update the speculative register map for the next cycle
            for (i = 0; i < 32; i = i + 1) begin
                updated_spec_reg_map[i] = new_spec_reg_map[i];
            end
        end
    end

endmodule
