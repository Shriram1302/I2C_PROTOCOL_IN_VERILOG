# I2C Protocol in Verilog 🔌

A **beginner-friendly, step-by-step Verilog implementation of the I2C protocol** — built one small building block at a time, then assembled into a full Master and Slave, and finally deployed on real FPGA hardware.

If you're learning digital design, FSMs, or communication protocols, this repo is meant to be **read in order**, like a tutorial, not just cloned and run.

---

## 📖 Table of Contents

1. [What is I2C?](#-what-is-i2c)
2. [How the Learning Path is Organized](#-how-the-learning-path-is-organized)
3. [Repository Structure](#-repository-structure)
4. [The I2C Frame — Visualized](#-the-i2c-frame--visualized)
5. [Building Blocks (I2C_master/)](#-building-blocks-i2c_master)
6. [Putting It Together — Master FSM](#-putting-it-together--master-fsm)
7. [The Slave (I2C_slave/)](#-the-slave-i2c_slave)
8. [Hardware Implementation (FPGA)](#-hardware-implementation-fpga)
9. [How to Simulate](#-how-to-simulate)
10. [Signal Cheat Sheet](#-signal-cheat-sheet)
11. [Suggested Learning Order](#-suggested-learning-order)

---

## 🧠 What is I2C?

**I2C (Inter-Integrated Circuit)** is a 2-wire serial communication protocol used to connect chips together — sensors, displays, EEPROMs, RTCs, etc.

It uses just two open-drain lines shared by every device on the bus:

| Line | Name | Purpose |
|------|------|---------|
| `SDA` | Serial Data  | Carries the actual bits |
| `SCL` / `SCK` | Serial Clock | Times when each bit is valid |

```mermaid
graph LR
    M["Master<br/>(FPGA)"] ---|SDA| BUS((I2C Bus))
    M ---|SCL| BUS
    BUS --- S1["Slave 1<br/>(e.g. sensor)"]
    BUS --- S2["Slave 2<br/>(e.g. display)"]
    BUS --- S3["Slave N..."]
```

Both lines are **open-drain**, meaning any device can pull them low, but nobody drives them high — a resistor does that. This is why you'll see `1'bz` (high-impedance) used a lot in this codebase instead of driving a `1` directly.

---

## 🪜 How the Learning Path is Organized

This project doesn't jump straight to a finished I2C master. It **teaches by decomposition**:

```mermaid
graph TD
    A["1️⃣ Tiny building blocks<br/>(start bit, one bit, ack...)"] --> B["2️⃣ Combine blocks into<br/>a full byte transfer"]
    B --> C["3️⃣ Combine bytes into a<br/>complete Master FSM (V1 → V2 → Final)"]
    C --> D["4️⃣ Build a matching Slave"]
    D --> E["5️⃣ Deploy Master + Slave<br/>on real FPGA boards"]
```

Each small block in `I2C_master/` has its **own Verilog module + its own testbench + a saved waveform screenshot**, so you can simulate and see exactly what one piece does before trusting it inside the bigger design.

---

## 🗂 Repository Structure

```
I2C_PROTOCOL_IN_VERILOG/
│
├── I2C_master/                     ← Learn the MASTER, piece by piece
│   ├── START_BIT/                  → generates the I2C START condition
│   ├── ADDRESS/
│   │   ├── send_bit/               → sends a single bit
│   │   ├── send_byte/              → sends 8 bits (uses send_bit)
│   │   └── read_byte/              → reads 8 bits from the slave
│   ├── ack/
│   │   ├── ack.v                   → master checks slave's ACK/NACK
│   │   ├── master_ack/             → master sends ACK (after reading)
│   │   └── master_nack/            → master sends NACK (end of read)
│   ├── Repeated_START/             → START without a STOP in between
│   ├── stop/                       → generates the I2C STOP condition
│   ├── I2C_Master V1/              → 1st full master (write-only)
│   ├── I2C_Master V2/              → 2nd full master (adds read + ack/nack)
│   └── I2C_Master Final V/         → complete master + testbench vs a slave model
│
├── I2C_slave/                      ← Learn the SLAVE, piece by piece
│   ├── slave_start_stop_detect.v   → detects START / STOP on the bus
│   ├── slave_receive_byte.v        → receives a byte (write from master)
│   ├── slave_send_byte.v           → sends a byte (read by master)
│   ├── slave_ack.v                 → slave generates ACK
│   └── i2c_slave.v                 → top-level slave FSM
│
├── Hardware_Implementation/
│   └── FPGA_Single_Slave/          ← Real, synthesizable FPGA design
│       ├── FPGA_Top_Master.v       → top module you load onto the MASTER FPGA
│       ├── I2C_master.v            → synthesizable master (reuses blocks above)
│       ├── I2C_Slave.v             → behavioral slave model for the bus
│       ├── Slave_1_top.v           → top module for a SLAVE FPGA
│       ├── Clock_divider.v         → slows the system clock down for SCL
│       ├── Master.xdc               → pin constraints for the master board
│       └── Slave_1.xcd              → pin constraints for the slave board
│
└── README.md
```

---

## ✉️ The I2C Frame — Visualized

Every I2C transaction follows the same shape. This is exactly what the FSM in `i2c_master.v` walks through:

```mermaid
sequenceDiagram
    participant M as Master
    participant S as Slave

    M->>S: START condition (SDA falls while SCL high)
    M->>S: Slave Address (7 bits) + R/W bit
    S-->>M: ACK
    M->>S: Register/Command Address (8 bits)
    S-->>M: ACK
    alt Write
        M->>S: Data byte (8 bits)
        S-->>M: ACK
    else Read (uses Repeated START)
        M->>S: Repeated START
        M->>S: Slave Address + R/W=1
        S-->>M: ACK
        S->>M: Data byte (8 bits)
        M-->>S: ACK / NACK
    end
    M->>S: STOP condition (SDA rises while SCL high)
```

**Key idea:** SCL must be **low** whenever SDA changes for a data bit, and SDA changes **while SCL is high** only for START and STOP — that's what makes those two conditions unambiguous.

---

## 🧩 Building Blocks (`I2C_master/`)

Each of these is a tiny FSM with a `stat_en` (start-enable) input and a `done` output — a pattern you'll see repeated everywhere, which makes them easy to chain together.

| Module | File | What it does |
|---|---|---|
| Start bit | `START_BIT/start_bit.v` | Pulls SDA low while SCL is high → START condition |
| Send 1 bit | `ADDRESS/send_bit/send_bit.v` | Drives a single SDA bit, timed with SCL |
| Send 1 byte | `ADDRESS/send_byte/send_byte.v` | Loops `send_bit` 8 times (MSB first) |
| Read 1 byte | `ADDRESS/read_byte/read_byte.v` | Samples SDA 8 times while master releases the line |
| Check ACK | `ack/ack.v` | Releases SDA, then checks if the slave pulled it low (ACK) |
| Master ACK | `ack/master_ack/master_ack.v` | Master pulls SDA low to ACK a byte it just read |
| Master NACK | `ack/master_nack/master_nack.v` | Master leaves SDA high to NACK (signals "stop sending") |
| Repeated start | `Repeated_START/repeated_start.v` | START condition issued mid-transaction (no STOP first) — used to switch from write to read |
| Stop bit | `stop/stop_i2c.v` | Releases SDA low→high while SCL is high → STOP condition |

Each folder also has:
- A `tb_*.v` testbench that exercises just that one module
- An `OUTPUT_*.png` waveform screenshot showing what "correct" looks like

👉 **Tip for learning:** open a block's `.v` file next to its testbench and waveform PNG side-by-side. You'll see cause → code → effect directly.

---

## 🔗 Putting It Together — Master FSM

`I2C_Master V1` → `I2C_Master V2` → `I2C_Master Final V` is the progression from "can only write" to "full read/write master with repeated START and ACK/NACK handling."

The **Final** master's FSM (from `Hardware_Implementation/FPGA_Single_Slave/I2C_master.v`) looks like this:

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> START_M: start pulse
    START_M --> LOAD_SLV_ADDR_W
    LOAD_SLV_ADDR_W --> SEND_SLV_ADDR_W
    SEND_SLV_ADDR_W --> ACK_SLV_ADDR_W
    ACK_SLV_ADDR_W --> LOAD_REG_ADDR: ACK ok
    ACK_SLV_ADDR_W --> STOP_M: NACK (error)
    LOAD_REG_ADDR --> SEND_REG_ADDR
    SEND_REG_ADDR --> ACK_REG_ADDR
    ACK_REG_ADDR --> LOAD_TX_DATA: write mode + ACK
    ACK_REG_ADDR --> REP_START_M: read mode + ACK
    ACK_REG_ADDR --> STOP_M: NACK (error)
    LOAD_TX_DATA --> SEND_TX_DATA
    SEND_TX_DATA --> ACK_TX_DATA
    ACK_TX_DATA --> STOP_M
    REP_START_M --> LOAD_SLV_ADDR_R
    LOAD_SLV_ADDR_R --> SEND_SLV_ADDR_R
    SEND_SLV_ADDR_R --> ACK_SLV_ADDR_R
    ACK_SLV_ADDR_R --> READ_DATA: ACK ok
    ACK_SLV_ADDR_R --> STOP_M: NACK (error)
    READ_DATA --> MASTER_NACK_M
    MASTER_NACK_M --> STOP_M
    STOP_M --> DONE_M
    DONE_M --> IDLE
```

Every state either drives one of the building blocks above (via its `stat_en`) or waits for that block's `done` signal — the FSM itself contains almost no I2C timing logic; it just **sequences** the reusable pieces.

---

## 🎯 The Slave (`I2C_slave/`)

The slave is built with the same "small pieces first" philosophy:

```mermaid
graph LR
    A["slave_start_stop_detect.v<br/>watches for START / STOP"] --> B["i2c_slave.v<br/>top FSM"]
    C["slave_receive_byte.v<br/>captures incoming byte"] --> B
    D["slave_send_byte.v<br/>drives outgoing byte"] --> B
    E["slave_ack.v<br/>ACK/NACK generation"] --> B
```

The slave constantly monitors SDA/SCL for edge patterns to detect START and STOP (it can't rely on a shared clock — it's asynchronous to the master), then walks its own FSM: address match → ACK → byte transfer → ACK → repeat or wait for STOP.

`tb_i2c_two_slaves_behav.wcfg` is a saved waveform config for testing **two slaves on the same bus**, so you can check that only the addressed slave responds.

---

## 🛠 Hardware Implementation (FPGA)

`Hardware_Implementation/FPGA_Single_Slave/` takes the simulation-only design and makes it **synthesizable and pin-mapped for real boards**:

```mermaid
graph TD
    subgraph "Master FPGA board"
        FT["FPGA_Top_Master.v"] --> IM["I2C_master.v"]
        IM --> CD["Clock_divider.v"]
        MX["Master.xdc<br/>(pin constraints)"] -.-> FT
    end
    subgraph "Slave FPGA board"
        ST["Slave_1_top.v"] --> IS["I2C_Slave.v"]
        SX["Slave_1.xcd<br/>(pin constraints)"] -.-> ST
    end
    FT ===|"SDA"| ST
    FT ===|"SCL"| ST
```

- **`FPGA_Top_Master.v`** wires up `i2c_master` with a target slave address (`7'h3C`) and register address, drives status LEDs for `done` and `ack_error`, and exposes `rx_data` for whatever you read back.
- **`Clock_divider.v`** slows the board's fast system clock down to a usable I2C `SCL` rate — this is necessary because FPGAs run in the 10s–100s of MHz, while I2C typically runs at 100kHz–400kHz.
- **`.xdc` / `.xcd` files** are Xilinx constraint files mapping the Verilog ports (`clk`, `sda`, `sck`, buttons, LEDs) to actual physical pins on each board.
- `sck`/`sda` are declared `inout` and driven with `1'bz`/`1'b0` (never `1'b1`) — this is the **open-drain** behavior real I2C hardware needs, backed up by external pull-up resistors on the board.

This is the payoff step: the exact same FSM and building blocks you simulated now run on silicon and talk across two physical boards over real wires.

---

## ▶️ How to Simulate

Using **Icarus Verilog** (`iverilog` + `vvp`), from inside any block's folder, e.g.:

```bash
cd I2C_master/START_BIT
iverilog -o sim start_bit.v tb_start_bit.v
vvp sim
# open the generated .vcd in GTKWave to see the waveform
gtkwave dump.vcd
```

For the full master, simulate from `I2C_master/I2C_Master Final V/`:

```bash
cd "I2C_master/I2C_Master Final V"
iverilog -o sim .i2c_master.v Clock_divider.v ack.v master_ack.v master_nack.v \
    read_byte.v repeated_start.v send_byte.v start_bit.v stop_i2c.v \
    i2c_slave.v tb_i2c_master.v
vvp sim
```

Or open any `.v`/testbench pair in **Vivado / ModelSim** if you prefer a GUI and want to compare against the saved `OUTPUT_*.png` screenshots.

---

## 🧾 Signal Cheat Sheet

| Signal | Width | Meaning |
|---|---|---|
| `clk` | 1 | Board/system clock (fast) |
| `rst` / `rst_n` | 1 | Active-low reset |
| `start` | 1 | Pulse to kick off a transaction |
| `rw` | 1 | `0` = write, `1` = read |
| `slave_addr` | 7 | Target slave's I2C address |
| `reg_addr` | 8 | Register/command byte sent after the address |
| `tx_data` | 8 | Byte to write (write mode) |
| `rx_data` | 8 | Byte received (read mode) |
| `sda` | 1 (`inout`) | Data line — open-drain (`1'b0` or `1'bz`, never `1'b1`) |
| `sck` / `scl` | 1 (`inout`) | Clock line — open-drain, same rule |
| `done` | 1 | Transaction finished |
| `ack_error` | 1 | Slave failed to ACK (address or data rejected) |

---

## 🗺 Suggested Learning Order

If you're new to I2C or FSM-based design, go in this order — it mirrors how the repo itself was built:

1. **`I2C_master/START_BIT/`** — smallest possible module, understand `stat_en` → `done` handshaking
2. **`I2C_master/ADDRESS/send_bit/`** → **`send_byte/`** — see how 8 single-bit sends become one byte
3. **`I2C_master/ack/`** — understand ACK/NACK detection and generation
4. **`I2C_master/ADDRESS/read_byte/`** and **`Repeated_START/`** and **`stop/`** — the remaining pieces
5. **`I2C_master/I2C_Master V1/`** → **`V2/`** → **`Final V/`** — watch the FSM grow as pieces are added
6. **`I2C_slave/`** — same idea, from the slave's point of view
7. **`Hardware_Implementation/FPGA_Single_Slave/`** — see it become real, synthesizable, pin-mapped hardware

---

*Built as a hands-on way to learn the I2C protocol and FSM-based digital design in Verilog — from a single wiggling wire to a working FPGA-to-FPGA link.*
