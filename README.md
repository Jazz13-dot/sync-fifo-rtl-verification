# RTL Design and Verification of a Parameterized Synchronous FIFO

Verilog RTL design and self-checking verification of an 8-bit × 16-deep synchronous FIFO, simulated on EDA Playground.
Project for **SD0212 RTL Design and Verification** (Employability Enhancement Course), Department of ECE, St. Joseph's College of Engineering, Chennai.

## Design

| Parameter | Value | Description |
|---|---|---|
| `DATA_WIDTH` | 8 | Width of each data word |
| `DEPTH` | 16 | Number of storage locations |
| `ADDR_WIDTH` | 4 | log2(DEPTH) |
| Pointer width | 5 bits | ADDR_WIDTH + 1 (extra wrap-around bit) |
| Clock / reset | Single clock, async active-low reset | |
| Read latency | 1 clock cycle | `dout` is registered |

**Ports:** `clk`, `rst_n`, `wr_en`, `rd_en`, `din[7:0]` → `dout[7:0]`, `full`, `empty`, `overflow`, `underflow`, `data_count[4:0]`

**Full / empty detection:** each pointer has one extra MSB that toggles on every wrap-around.

```
empty      = (wr_ptr == rd_ptr)
full       = (wr_ptr[4] != rd_ptr[4]) && (wr_ptr[3:0] == rd_ptr[3:0])
data_count = wr_ptr - rd_ptr
```

Writes are blocked when the FIFO is full and reads are blocked when it is empty. `overflow` and `underflow` pulse for one cycle when this happens.

## Files

| File | Contents |
|---|---|
| `design.sv` | RTL of the parameterized synchronous FIFO (`sync_fifo`) |
| `testbench.sv` | Self-checking testbench with a reference model and scoreboard (`tb_sync_fifo`) |

## Running it

**EDA Playground:** paste `design.sv` and `testbench.sv` into their panes, select **Icarus Verilog 12.0** with options `-Wall -g2012`, tick **Open EPWave after run**, and click **Run**.

**Locally:**

```bash
iverilog -g2012 -Wall -o sim design.sv testbench.sv
vvp sim
```

## Verification

| Test | Scenario | Result |
|---|---|---|
| T1 | Reset | PASS |
| T2 | Write till full (A0h–AFh) | PASS |
| T3 | Overflow attempt | PASS |
| T4 | Read till empty, data order checked | PASS |
| T5 | Underflow attempt | PASS |
| T6 | Simultaneous read and write | PASS |
| T7 | 300 cycles of constrained-random traffic | PASS |

Simulation output (Icarus Verilog 12.0):

```
TEST 1 : Reset check ............ PASS (empty=1 full=0 count=0)
TEST 2 : Write till full ........ PASS (full=1 count=16)
TEST 3 : Overflow attempt ....... PASS (overflow=1 count=16)
TEST 4 : Read till empty ........ PASS (empty=1 last dout=af)
TEST 5 : Underflow attempt ...... PASS (underflow=1 count=0)
TEST 6 : Simultaneous rd/wr ..... PASS (count=2 dout=22)
TEST 7 : 300 random cycles ...... PASS (total writes=107 reads=106)
--------------------------------------------------------
Scoreboard checks = 384, Errors = 0
RESULT: ALL TESTS PASSED
--------------------------------------------------------
```

## Synthesis (Yosys, generic gates)

| Cell type | Count |
|---|---|
| D flip-flops (memory, wr_ptr, rd_ptr, dout, error flags) | 148 |
| Combinational cells (AND, NAND, OR, NOR, XOR, XNOR, NOT, MUX) | 393 |
| **Total** | **541** |

No latches were inferred.

## Team

Jaswant S M, Aditya K, Harish K, Balaganesh D, Kamalesh P M

Supervisor: Dr. P. Latha, Associate Professor, Department of ECE
