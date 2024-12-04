# performance-relay-isac
This repository contains the code used in my bachelor's thesis at HUST.
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>

// CPU structure definition
typedef struct {
    uint8_t PC;          // Program Counter
    uint8_t R[4];        // General-purpose registers R0 to R3
    struct {
        bool ZF;         // Zero Flag
        bool OF;         // Overflow Flag
    } SR;                // Status Register
} CPU;

// Memory definitions
#define ROM_SIZE 128
#define RAM_SIZE 128

uint8_t ROM[ROM_SIZE];   // Program ROM from address 0x00 to 0x7F
uint8_t RAM[RAM_SIZE];   // Data RAM from address 0x80 to 0xFF

// Function prototypes
void fetch(uint8_t *instruction);
void decode_execute(uint8_t instruction);
void load_program(const uint8_t *program, size_t size);

// Global CPU instance
CPU cpu;

// Function implementations

/**
 * @brief Fetches the next instruction from the ROM.
 *
 * This function reads the instruction at the current Program Counter (PC)
 * from the ROM and increments the PC. If PC reaches the end of the ROM,
 * it wraps around to 0.
 *
 * @param instruction Pointer to store the fetched instruction.
 */
void fetch(uint8_t *instruction) {
    *instruction = ROM[cpu.PC];
    cpu.PC = (cpu.PC + 1) % ROM_SIZE;
}

/**
 * @brief Decodes and executes the fetched instruction.
 *
 * This function decodes the opcode, sub-opcode, and operands from the instruction,
 * and performs the corresponding operation as per the instruction set provided.
 * It handles data transfer, arithmetic, bit shift, comparison, I/O, and branch instructions.
 *
 * @param instruction The instruction byte fetched from ROM.
 */
void decode_execute(uint8_t instruction) {
    uint8_t opcode = (instruction >> 4) & 0x0F;     // Bits 7-4
    uint8_t dd = (instruction >> 2) & 0x03;         // Bits 3-2 (sub-opcode or don't care)
    uint8_t xx = instruction & 0x03;                // Bits 1-0
    uint8_t yy = instruction & 0x03;                // Bits 1-0 (when needed)
    uint8_t immediate = instruction & 0x0F;         // Bits 3-0 (for immediate value)

    switch (opcode) {
        case 0x0:  // 0000: LOAD/STORE Memory and R0
            if (dd == 0x00) {
                // LOAD: Transfer data from memory into R0
                uint8_t addr = xx;
                uint8_t data = (addr < 0x80) ? ROM[addr] : RAM[addr - 0x80];
                cpu.R[0] = data;
                cpu.SR.ZF = (cpu.R[0] == 0);
            } else if (dd == 0x01) {
                // STORE: Transfer data from R0 into memory
                uint8_t addr = xx;
                uint8_t data = cpu.R[0];
                if (addr >= 0x80) {
                    RAM[addr - 0x80] = data;
                } else {
                    // Cannot write to ROM; handle error or ignore
                }
                cpu.SR.ZF = (data == 0);
            }
            break;
        case 0x1:  // 0001: Transfer between Registers (RX → RY)
            {
                uint8_t rx = (instruction >> 2) & 0x03;  // Bits 3-2
                uint8_t ry = instruction & 0x03;         // Bits 1-0
                cpu.R[ry] = cpu.R[rx];
                cpu.SR.ZF = (cpu.R[ry] == 0);
            }
            break;
        case 0x2:  // 0010: Immediate Value Setting into R0
            {
                cpu.R[0] = immediate;
                cpu.SR.ZF = (cpu.R[0] == 0);
            }
            break;
        case 0x3:  // 0011: ADD RX + RY → RX
            {
                uint8_t rx = (instruction >> 2) & 0x03;  // Bits 3-2
                uint8_t ry = instruction & 0x03;         // Bits 1-0
                uint16_t result = cpu.R[rx] + cpu.R[ry];
                cpu.SR.OF = (result > 0xFF);             // Overflow if result exceeds 255
                cpu.R[rx] = (uint8_t)result;             // Store the lower 8 bits
                cpu.SR.ZF = (cpu.R[rx] == 0);
            }
            break;
        case 0x4:  // 0100: SUB RX - RY → RX
            {
                uint8_t rx = (instruction >> 2) & 0x03;  // Bits 3-2
                uint8_t ry = instruction & 0x03;         // Bits 1-0
                int16_t result = (int16_t)cpu.R[rx] - (int16_t)cpu.R[ry];
                cpu.SR.OF = (result < 0);                // Overflow if result is negative
                cpu.R[rx] = (uint8_t)result;             // Store the lower 8 bits
                cpu.SR.ZF = (cpu.R[rx] == 0);
            }
            break;
        case 0x5:  // 0101: SHIFT Operations
            if (dd == 0x00) {
                // LEFT SHIFT RX << 4 → RX
                uint8_t rx = xx;
                cpu.R[rx] <<= 4;
                // STATUS not updated
            } else if (dd == 0x01) {
                // RIGHT SHIFT RX >> 4 → RX
                uint8_t rx = xx;
                cpu.R[rx] >>= 4;
                // STATUS not updated
            }
            break;
        case 0x6:  // 0110: CMP RX == 0 or OUTPUT RX
            if (dd == 0x00) {
                // COMPARE RX == 0
                uint8_t rx = xx;
                cpu.SR.ZF = (cpu.R[rx] == 0);
            } else if (dd == 0x01) {
                // OUTPUT RX
                uint8_t rx = xx;
                printf("Output from R%d: %u\n", rx, cpu.R[rx]);
            }
            break;
        case 0x7:  // 0111: INPUT into RX
            {
                uint8_t rx = xx;
                printf("Enter value for R%d (0-255): ", rx);
                scanf("%hhu", &cpu.R[rx]);
            }
            break;
        case 0xE:  // 1110: Conditional Branch if Zero Flag is set
            {
                uint8_t rx = xx;
                if (cpu.SR.ZF) {
                    cpu.PC = cpu.R[rx];
                }
            }
            break;
        case 0xF:  // 1111: Unconditional Branch
            {
                uint8_t rx = xx;
                cpu.PC = cpu.R[rx];
            }
            break;
        default:
            // Invalid opcode; handle error
            printf("Invalid opcode: 0x%X at PC: 0x%X\n", opcode, cpu.PC);
            break;
    }
}

/**
 * @brief Loads a program into the ROM.
 *
 * This function copies the program code into the ROM array, up to the maximum
 * ROM size. It ensures that the program does not exceed the ROM capacity.
 *
 * @param program Pointer to the array containing the program code.
 * @param size Size of the program code in bytes.
 */
void load_program(const uint8_t *program, size_t size) {
    if (size > ROM_SIZE) {
        size = ROM_SIZE;  // Truncate program if it exceeds ROM size
    }
    memcpy(ROM, program, size);
}

/**
 * @brief Main function to initialize and run the CPU simulator.
 *
 * This function initializes the CPU and memory, loads a sample program,
 * and starts the fetch-decode-execute loop. It runs until it reaches a NOP instruction.
 *
 * @return int Exit code of the program.
 */
int main() {
    // Initialize CPU
    memset(&cpu, 0, sizeof(cpu));

    // Sample program demonstrating addition overflow
    uint8_t program[] = {
        0x20, 0xF0,   // 0010 0000: Immediate value 0xF0 into R0 (240)
        0x21, 0x20,   // 0010 0001: Immediate value 0x20 into R1 (32)
        0x33,         // 0011 0011: ADD R0 + R1 -> R0 (R0 = 240 + 32 = 272)
        // Expected overflow since 272 > 255
        0x65,         // 0110 0101: OUTPUT R0
        // Check overflow flag
        0x60,         // 0110 0000: COMPARE R0 == 0
        0xE0,         // 1110 0000: Conditional Branch to R0 if Zero Flag is set
        // NOP (end of program)
        0x00
    };

    // Load program into ROM
    load_program(program, sizeof(program));

    // Main loop
    while (1) {
        uint8_t instruction;
        fetch(&instruction);
        if (instruction == 0x00) {
            // NOP or HALT
            break;
        }
        decode_execute(instruction);
    }

    // After execution, check the Overflow Flag
    if (cpu.SR.OF) {
        printf("Overflow occurred during addition.\n");
    } else {
        printf("No overflow occurred.\n");
    }

    return 0;
}





uint8_t program[] = {
    0x20, 0x01, // 0x00: Load immediate 1 into R0
    0x11,       // 0x02: Move R0 to R1
    0x20, 0x05, // 0x03: Load immediate 5 into R0
    0x12,       // 0x05: Move R0 to R2
    0x62,       // 0x06: Label_Loop: Compare R2 with 0
    0x20, 0x20, // 0x07: Load address of End (0x20) into R0
    0xE0,       // 0x09: Conditional Branch to R0 if Zero
    0x20, 0x00, // 0x0A: Load immediate 0 into R3
    0x13,       // 0x0C: Move R3 to R3 (clear R3)
    0x12,       // 0x0D: Move R2 to R0 (inner_counter)
    0x60,       // 0x0E: Label_Mult: Compare R0 with 0
    0x21, 0x19, // 0x0F: Load address of After_Mult (0x19) into R1
    0xE1,       // 0x11: Conditional Branch to R1 if Zero
    0x3F,       // 0x12: Add R1 to R3, result in R3
    0x20, 0x01, // 0x13: Load immediate 1 into R3
    0x43,       // 0x15: Subtract R3 from R0, result in R0
    0x20, 0x0E, // 0x16: Load address of Label_Mult (0x0E) into R0
    0xF0,       // 0x18: Unconditional Branch to R0
    0x1E,       // 0x19: After_Mult: Move R3 to R1
    0x20, 0x01, // 0x1A: Load immediate 1 into R0
    0x4A,       // 0x1C: Subtract R0 from R2, result in R2
    0x20, 0x06, // 0x1D: Load address of Label_Loop (0x06) into R0
    0xF0,       // 0x1F: Unconditional Branch to R0
    0x65,       // 0x20: End: Output R1
    0x00        // 0x21: NOP (End of Program)
};
