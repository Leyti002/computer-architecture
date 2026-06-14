# Lab 2 — RAID Performance & Fault Tolerance

**Course:** Computer Architecture  
**Student:** Oumar Leyti Ndiaye | A00228981

## Overview
Performance benchmarking and fault tolerance testing of
RAID 0, 1, 5 and 6 configurations using simulated virtual disks.

## Results
| File | Configuration |
|------|--------------|
| RAID0-1.txt | RAID 0 — 1 disk |
| RAID0-2.txt | RAID 0 — 2 disks |
| RAID0-4.txt | RAID 0 — 4 disks |
| RAID0-8.txt | RAID 0 — 8 disks |
| RAID0-16.txt | RAID 0 — 16 disks |
| RAID1-1.txt | RAID 1 — 1 disk |
| RAID1-2.txt | RAID 1 — 2 disks |
| RAID1-4.txt | RAID 1 — 4 disks |
| RAID1-8.txt | RAID 1 — 8 disks |
| RAID1-16.txt | RAID 1 — 16 disks |
| RAID5-1fail.txt | RAID 5 — 1 disk failure |
| RAID5-1rebuild.txt | RAID 5 — rebuild after 1 failure |
| RAID5-2fail.txt | RAID 5 — 2 disk failures |
| RAID6-2fail.txt | RAID 6 — 2 disk failures |
| RAID6-2rebuild.txt | RAID 6 — rebuild after 2 failures |

## Tools
- Linux mdadm
- dmsetup
- bench_disk.sh
