# Lab 1 — RGB to Grayscale Conversion (NASM)

**Course:** Computer Architecture  
**Student:** Oumar Leyti Ndiaye | A00228981

## Overview
Implementation of RGB to grayscale conversion using three
different x86_64 assembly approaches (ITU-R BT.2020 formula).

## Implementations
| File | Method | Description |
|------|--------|-------------|
| rgb2gray-x87.asm | x87 FPU | Scalar, one pixel at a time |
| rgb2gray-sse2.asm | SSE2 | Scalar with XMM registers |
| rgb2gray-avx2.asm | AVX2 | Vectorized, 8 pixels at a time |
| rgb2gray-x87-bench.asm | x87 | 100,000 iterations benchmark |
| rgb2gray-sse2-bench.asm | SSE2 | 100,000 iterations benchmark |
| rgb2gray-avx2-bench.asm | AVX2 | 100,000 iterations benchmark |

## Formula Used
Gray = 0.2627 × R + 0.6780 × G + 0.0593 × B
(ITU-R BT.2020 standard)

## How to Compile
```bash
nasm -felf64 rgb2gray-x87.asm
nasm -felf64 rgb2gray-sse2.asm
nasm -felf64 rgb2gray-avx2.asm
```

## Tools
- NASM 2.16.03
- Linux x86_64
