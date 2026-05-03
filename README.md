# Custom RTOS Kernel (M68k)

A custom Real-Time Operating System kernel implemented in Motorola 68000 (M68k) Assembly for embedded systems coursework at Newcastle University.

## Overview

This project implements a lightweight RTOS kernel supporting:
- **Concurrent task management** - Up to 8 simultaneous tasks
- **Preemptive time-sliced scheduling** - Timer-driven context switching
- **Mutex synchronization** - Binary semaphores for critical section protection
- **System calls** - Create, delete, wait, signal operations via TRAP instructions

## Technical Specifications

| Specification | Value |
|--------------|-------|
| Architecture | Motorola 68000 (M68k) |
| Assembly | Motorola syntax (EASy68K) |
| Max Tasks | 8 concurrent tasks |
| Scheduling | Round-robin, timer-based |
| Memory Model | Memory-mapped I/O |

## Key Features Implemented

- **Context Switching**: Full register save/restore (D0-D7, A0-A7, PC, SR)
- **Timer-based ISR**: Level 1 hardware interrupt driving scheduler
- **TCB (Task Control Block)**: Custom 84-byte structure per task
- **Mutex Operations**: Initialize, wait, signal with queue management
- **System Call Interface**: TRAP #0 with function codes in D0

## Project Structure

```
Custom-RTOS-Kernel-M68k/
├── RTOS_Skeleton.asm    # Complete RTOS kernel source
├── RTOS_DOCS_GUIDE.pdf  # Technical documentation
├── DOCS.md              # Implementation notes
└── screenshots/         # Test results & validation
```

## System Calls

| Call | Code | Description |
|------|------|-------------|
| sys_create | 1 | Create new task |
| sys_delete | 2 | Delete existing task |
| sys_init_mutex | 5 | Initialize mutex |
| sys_wait_mutex | 3 | Acquire mutex |
| sys_signal_mutex | 4 | Release mutex |
| sys_wait_time | 6 | Delay task |

## My Contribution

As part of a collaborative team project, I was responsible for:

- **Test Program Implementation**: Developed test programs validating kernel functionality
- **Radiation Monitor (prog2)**: Multi-task application demonstrating concurrent operations
- **Error Handling (prog3)**: Testing boundary conditions and failure modes
- **Testing & Validation**: Comprehensive testing procedures and results documentation

## Getting Started

This kernel was developed using the **EASy68K** assembler and simulator. To run:

1. Open `RTOS_Skeleton.asm` in EASy68K
2. Assemble the code (F5)
3. Load into simulator (F6)
4. Run and observe task scheduling

## Learning Outcomes

- Deep understanding of RTOS fundamentals (scheduling, context switching)
- Low-level systems programming in assembly
- Critical section management and synchronization
- Hardware interrupt handling and timer configuration

## License

Academic project - Newcastle University EEE8087 Coursework

---

*This implementation demonstrates core RTOS concepts including task management, scheduling algorithms, and inter-task synchronization using mutexes.*