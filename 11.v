// ============================================================
// 32-BIT RISC-V SINGLE CYCLE PROCESSOR
// Supports:
// R-type : ADD, SUB, AND, OR
// I-type : LW, ADDI, ORI
// S-type : SW
// B-type : BEQ
// ============================================================


// ============================================================
// PROGRAM COUNTER
// ============================================================
module program_counter(clk, reset, pc_in, pc_out);

input clk, reset;
input [31:0] pc_in;
output reg [31:0] pc_out;

always @(posedge clk or posedge reset)
begin
    if(reset)
        pc_out <= 32'b00;
    else
        pc_out <= pc_in;
end

endmodule


// ============================================================
// PC + 4
// ============================================================
module pcplus4(frompc, nextopc);

input [31:0] frompc;
output [31:0] nextopc;

assign nextopc = 4 + frompc;

endmodule


// ============================================================
// INSTRUCTION MEMORY
// ============================================================
module instruction_mem(clk, reset, read_address, instruction_out);

input clk, reset;
input [31:0] read_address;
output [31:0] instruction_out;

integer k;
reg [31:0] IMemory [63:0];

assign instruction_out = IMemory[read_address];

initial begin
    for(k = 0; k < 64; k = k + 1) begin
        IMemory[k] = 32'b0;
    end

    IMemory[0]  = 32'b00000000000000000000000000000000;  // no operation
    IMemory[4]  = 32'b0000000_11001_10000_000_01101_0110011;  // add x13, x16, x25
    IMemory[8]  = 32'b0100000_00011_01000_000_00101_0110011;  // sub x5, x8, x3
    IMemory[12] = 32'b0000000_00011_00010_111_00001_0110011;  // and x1, x2, x3
    IMemory[16] = 32'b0000000_00101_00011_110_00100_0110011;  // or  x4, x3, x5

    IMemory[20] = 32'b000000000011_10101_000_10110_0010011;  // addi x22, x21, 3
    IMemory[24] = 32'b000000000001_01000_110_01001_0010011;  // ori x9, x8, 1

    IMemory[28] = 32'b000000001111_00101_010_01000_0000011;  // lw x8, 15(x5)
    IMemory[32] = 32'b000000000011_00011_010_01001_0000011;  // lw x9, 3(x3)

    IMemory[36] = 32'b0000000_01111_00101_010_01100_0100011;  // sw x15, 12(x5)
    IMemory[40] = 32'b0000000_01110_00110_010_01010_0100011;  // sw x14, 10(x6)

    IMemory[44] = 32'h00948663;  // beq x9, x9, 12
end

endmodule


// ============================================================
// REGISTER FILE
// ============================================================
module reg_file(
    clk,
    reset,
    regwrite,
    rs1,
    rs2,
    rd,
    write_data,
    read_data1,
    read_data2
);

input clk, reset, regwrite;
input [4:0] rs1, rs2, rd;
input [31:0] write_data;
output [31:0] read_data1, read_data2;

integer k;
reg [31:0] registers [31:0];

initial begin
    registers[0]  = 0;
    registers[1]  = 4;
    registers[2]  = 2;
    registers[3]  = 24;
    registers[4]  = 4;
    registers[5]  = 1;
    registers[6]  = 44;
    registers[7]  = 4;
    registers[8]  = 2;
    registers[9]  = 1;
    registers[10] = 23;
    registers[11] = 4;
    registers[12] = 90;
    registers[13] = 10;
    registers[14] = 20;
    registers[15] = 30;
    registers[16] = 40;
    registers[17] = 50;
    registers[18] = 60;
    registers[19] = 70;
    registers[20] = 80;
    registers[21] = 80;
    registers[22] = 90;
    registers[23] = 90;
    registers[24] = 70;
    registers[25] = 65;
    registers[26] = 4;
    registers[27] = 32;
    registers[28] = 12;
    registers[29] = 34;
    registers[30] = 5;
    registers[31] = 10;
end

always @(posedge clk)
begin
    if(reset)
    begin
        for(k = 0; k < 32; k = k + 1) begin
            registers[k] <= 32'b0;
        end
    end
    else if(regwrite && (rd != 5'b0))
    begin
        registers[rd] <= write_data;
    end
end

assign read_data1 = registers[rs1];
assign read_data2 = registers[rs2];

endmodule


// ============================================================
// IMMEDIATE GENERATOR
// ============================================================
module immgen(opcode, instruction, immext);

input [6:0] opcode;
input [31:0] instruction;
output reg [31:0] immext;

always @(*)
begin
    case(opcode)
        // LW / I-type Arithmetic (ADDI, ORI)
        7'b0000011, 7'b0010011:
            immext = {{20{instruction[31]}}, instruction[31:20]};

        // SW - S type
        7'b0100011:
            immext = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

        // BEQ - B type
        7'b1100011:
            immext = {{19{instruction[31]}}, instruction[31], instruction[30:25], instruction[11:8], 1'b0};

        default:
            immext = 32'b0;
     endcase
end

endmodule


// ============================================================
// CONTROL UNIT
// ============================================================
module control_unit(
    instruction,
    branch,
    memread,
    memtoreg,
    aluop,
    memwrite,
    alusrc,
    regwrite
);

input [6:0] instruction;
output reg branch;
output reg memread;
output reg memtoreg;
output reg memwrite;
output reg alusrc;
output reg regwrite;
output reg [1:0] aluop;

always @(*)
begin
    case(instruction)
        // R-type
        7'b0110011:
        begin
            {alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop} = 8'b001000_10;
        end

        // I-type Arithmetic (ADDI, ORI)
        7'b0010011:
        begin
            {alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop} = 8'b101000_11;
        end

        // LW
        7'b0000011:
        begin
            {alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop} = 8'b111100_00;
        end

        // SW
        7'b0100011:
        begin
            {alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop} = 8'b100010_00;
        end

        // BEQ
        7'b1100011:
        begin
            {alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop} = 8'b000001_01;
        end

        default:
        begin
            {alusrc, memtoreg, regwrite, memread, memwrite, branch, aluop} = 8'b000000_00;
        end
    endcase
end    

endmodule


// ============================================================
// ALU
// ============================================================
module alu_unit(
    a,
    b,
    control_in,
    alu_result,
    zero
);

input [31:0] a, b;
input [3:0] control_in;
output reg [31:0] alu_result;
output reg zero;

always @(*)
begin
    case(control_in)
        // AND
        4'b0000:
        begin
            zero = 0;  
            alu_result = a & b;
        end

        // OR
        4'b0001:
        begin
            zero = 0;  
            alu_result = a | b;
        end

        // ADD
        4'b0010:
        begin
            zero = 0;  
            alu_result = a + b;
        end

        // SUB
        4'b0110:
        begin
            if (a == b) 
                zero = 1; 
            else 
                zero = 0; 
            
            alu_result = a - b;
        end

        default:
        begin
            zero = 0;
            alu_result = 32'b0;
        end
     endcase
end
endmodule


// ============================================================
// ALU CONTROL
// ============================================================
module alu_control(
    aluop,
    fun7,
    fun3,
    control_out
);

input [1:0] aluop;
input fun7;
input [2:0] fun3;

output reg [3:0] control_out;

always @(*)
begin
    case(aluop)
        2'b00: control_out = 4'b0010; // LW / SW -> ADD
        2'b01: control_out = 4'b0110; // BEQ -> SUB
        2'b10: begin                  // R-type
            case({fun7, fun3})
                5'b0_000: control_out = 4'b0010; // ADD
                5'b1_000: control_out = 4'b0110; // SUB
                5'b0_111: control_out = 4'b0000; // AND
                5'b0_110: control_out = 4'b0001; // OR
                default:  control_out = 4'b0000;
            endcase
        end
        2'b11: begin                  // I-type Arithmetic (ADDI, ORI)
            case(fun3)
                3'b000:   control_out = 4'b0010; // ADDI -> ADD
                3'b110:   control_out = 4'b0001; // ORI -> OR
                3'b111:   control_out = 4'b0000; // ANDI -> AND
                default:  control_out = 4'b0000;
            endcase
        end
        default: control_out = 4'b0000;
    endcase
end
endmodule


// ============================================================
// DATA MEMORY
// ============================================================
module data_memory(
    clk,
    reset,
    memwrite,
    memread,
    read_address,
    write_data,
    memdata_out
);

input clk, reset;
input memwrite, memread;
input [31:0] read_address;
input [31:0] write_data;
output [31:0] memdata_out;

integer k;
reg [31:0] d_memory [63:0];

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        for(k = 0; k < 64; k = k + 1) begin
            d_memory[k] <= 32'b00;
        end
    end    
    else if(memwrite)
    begin
        d_memory[read_address] <= write_data;
    end
end

assign memdata_out = (memread) ? d_memory[read_address] : 32'b00;

endmodule


// ============================================================
// MUX 1
// ============================================================
module mux1(sel1, a1, b1, mux1_out);

input sel1;
input [31:0] a1, b1;
output [31:0] mux1_out;

assign mux1_out = (sel1 == 1'b0) ? a1 : b1;

endmodule


// ============================================================
// MUX 2
// ============================================================
module mux2(sel2, a2, b2, mux2_out);

input sel2;
input [31:0] a2, b2;
output [31:0] mux2_out;

assign mux2_out = (sel2 == 1'b0) ? a2 : b2;

endmodule


// ============================================================
// MUX 3
// ============================================================
module mux3(sel3, a3, b3, mux3_out);

input sel3;
input [31:0] a3, b3;
output [31:0] mux3_out;

assign mux3_out = (sel3 == 1'b0) ? a3 : b3;

endmodule


// ============================================================
// AND LOGIC
// ============================================================
module and_logic(branch, zero, and_out);

input branch, zero;
output and_out;

assign and_out = branch & zero;

endmodule


// ============================================================
// ADDER
// ============================================================
module adder(in_1, in_2, sum_out);

input [31:0] in_1, in_2;
output [31:0] sum_out;

assign sum_out = in_1 + in_2;

endmodule


// ============================================================
// TOP MODULE
// ============================================================
module top(clk, reset);

input clk, reset;

// WIRES
wire [31:0] pc_top;
wire [31:0] pc_plus4;
wire [31:0] instruction_top;

wire [31:0] read_data1;
wire [31:0] read_data2;

wire [31:0] immext;

wire [31:0] alu_input2;
wire [31:0] alu_result;
wire alu_zero;

wire [31:0] memdata_out;
wire [31:0] writeback_data;

wire [31:0] branch_target;
wire [31:0] next_pc;

wire branch_taken;

// INSTRUCTION FIELDS
wire [6:0] opcode;
wire [4:0] rs1;
wire [4:0] rs2;
wire [4:0] rd;

wire [2:0] fun3;
wire fun7;

assign opcode = instruction_top[6:0];
assign rd     = instruction_top[11:7];
assign fun3   = instruction_top[14:12];
assign rs1    = instruction_top[19:15];
assign rs2    = instruction_top[24:20];
assign fun7   = instruction_top[30];

// CONTROL SIGNALS
wire branch;
wire memread;
wire memtoreg;
wire memwrite;
wire alusrc;
wire regwrite;

wire [1:0] aluop;
wire [3:0] alu_control_signal;

// PROGRAM COUNTER
program_counter pc(
    .clk(clk),
    .reset(reset),
    .pc_in(next_pc),
    .pc_out(pc_top)
);

// PC + 4
pcplus4 pc_adder(
    .frompc(pc_top),
    .nextopc(pc_plus4)
);

// INSTRUCTION MEMORY
instruction_mem inst_memory(
    .clk(clk),
    .reset(reset),
    .read_address(pc_top),
    .instruction_out(instruction_top)
);

// CONTROL UNIT
control_unit control(
    .instruction(opcode),
    .branch(branch),
    .memread(memread),
    .memtoreg(memtoreg),
    .aluop(aluop),
    .memwrite(memwrite),
    .alusrc(alusrc),
    .regwrite(regwrite)
);

// REGISTER FILE
reg_file registers(
    .clk(clk),
    .reset(reset),
    .regwrite(regwrite),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .write_data(writeback_data),
    .read_data1(read_data1),
    .read_data2(read_data2)
);

// IMMEDIATE GENERATOR
immgen immediate_generator(
    .opcode(opcode),
    .instruction(instruction_top),
    .immext(immext)
);

// ALU SOURCE MUX
mux1 alu_src_mux(
    .sel1(alusrc),
    .a1(read_data2),
    .b1(immext),
    .mux1_out(alu_input2)
);

// ALU CONTROL
alu_control alu_ctrl(
    .aluop(aluop),
    .fun7(fun7),
    .fun3(fun3),
    .control_out(alu_control_signal)
);

// ALU
alu_unit alu(
    .a(read_data1),
    .b(alu_input2),
    .control_in(alu_control_signal),
    .alu_result(alu_result),
    .zero(alu_zero)
);

// DATA MEMORY
data_memory data_mem(
    .clk(clk),
    .reset(reset),
    .memwrite(memwrite),
    .memread(memread),
    .read_address(alu_result),
    .write_data(read_data2),
    .memdata_out(memdata_out)
);

// WRITEBACK MUX
mux2 writeback_mux(
    .sel2(memtoreg),
    .a2(alu_result),
    .b2(memdata_out),
    .mux2_out(writeback_data)
);

// BRANCH TARGET
adder branch_adder(
    .in_1(pc_top),
    .in_2(immext),
    .sum_out(branch_target)
);

// BRANCH AND ZERO
and_logic branch_logic(
    .branch(branch),
    .zero(alu_zero),
    .and_out(branch_taken)
);

// NEXT PC MUX
mux3 pc_mux(
    .sel3(branch_taken),
    .a3(pc_plus4),
    .b3(branch_target),
    .mux3_out(next_pc)
);

endmodule


// ============================================================
// TESTBENCH
// ============================================================
module tb_top;

    reg clk, reset;

    top uut(.clk(clk), .reset(reset));

    initial begin
        // --- ADD THESE LINES FOR GTKWAVE ---
        $dumpfile("riscv_waveform.vcd");
        $dumpvars(0, tb_top);
        // -----------------------------------

        clk = 0;
        reset = 1;
        #5;
        reset = 0;
        #400;
        $finish;
    end

    always begin
        #5 clk = ~clk;
    end

endmodule