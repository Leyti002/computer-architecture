# Computer Architecture 

**author:** Oumar Leyti Ndiaye | A00228981  


## Overview
Assembly programming and system architecture labs using
x86_64 NASM on Linux.

## Labs

### [Lab 1 — RGB to Grayscale Conversion](./Lab1-RGB-Grayscale-NASM/)
Implementation of an RGB to grayscale image conversion in x86_64
assembly using three different approaches based on the ITU-R BT.2020
formula (Gray = 0.2627×R + 0.6780×G + 0.0593×B).
- **x87 FPU** — scalar conversion using the legacy x87 floating-point unit
- **SSE2** — scalar conversion using XMM registers and SSE2 instructions
- **AVX2** — fully vectorized conversion processing 8 pixels simultaneously
- Each version includes a benchmark variant running 100,000 iterations
for performance comparison

### [Lab 2 — RAID Performance & Fault Tolerance](./Lab2-RAID/)
Performance benchmarking and fault tolerance testing of four RAID
configurations using simulated virtual disks with artificial I/O delay.
- **RAID 0** — striping across 1, 2, 4, 8 and 16 disks (performance scaling)
- **RAID 1** — mirroring across 1, 2, 4, 8 and 16 disks (redundancy)
- **RAID 5** — single disk failure, rebuild, and double disk failure scenarios
- **RAID 6** — double disk failure and rebuild with 4-disk array

## Technologies
- NASM 2.16.03 (x86_64 Assembly)
- x87 FPU, SSE2, AVX2
- Linux mdadm, dmsetup
- Ubuntu/Linux x86_64
