#!/usr/bin/env python3
"""Generates a CSV of ROWS rows and turns it into a Silica storage log (__ignore__data.sildat) that the
regression program replays.

The data: hours studied (x, 0.00 to 10.00) against exam score (y = 6.0 x + 45.0 plus Gaussian noise
with a standard deviation of 3.0), rounded to two decimals, from a fixed seed so every run writes the
same file. A fit should come out near slope 6.0 and intercept 45.0.

Silica has no files, paths or directories (transport_serialization_design.md §6.8). A program can only
keep or read bytes through a storage carrier: a `(:store)` declaration whose `(:backing, path,
capacity, retention)` link names a host file ending in `.sildat`. That file holds an append-only log
of records, not text. So the CSV must be put into that form. This script does it for the hosted
backing, the way the Silica trials' make_backings.py does, without depending on any Silica code.

Each non-empty line of the CSV, the header included, becomes one stored value: the line as a Silica
`string`. The Silica program decodes each value and parses it as CSV there. The layers, from the
outside in (§6.8.3, §6.8.4, §6.8.9):

  block     4096 bytes: a 16-byte header { first_seq: u64, state: u32 = 1, crc32c: u32 } and then
            records packed back to back. A record never spans two blocks.
  envelope  { length: u32, seq: u64, crc32c over length, seq and payload: u32 } and then the payload.
  segment   wireframe's :storage header { frame_seq: u16 = 0, index: u16 } with bit 15 of index set
            on the last segment. One line fits in one record, so it is always index 0 | 0x8000.
  record    wireframe@record: a format id (1 = :etf) and a two-byte schema version (SCHEMA below).
  value     the ETF encoding of a Silica string: 131, 109 (BINARY_EXT), length: u32, then the bytes.

All integers are big-endian. The file is written at exactly CAPACITY bytes because the carrier
refuses a backing of another size with (:link_down, :mismatch).

usage: csv_to_sildat.py          generate __ignore__data.csv (ROWS rows) beside this script, then convert it
       csv_to_sildat.py CSV      convert your own CSV instead (x first, y second)
       writes __ignore__data.sildat beside this script, replacing any earlier one
"""
import os
import random
import struct
import sys

ROWS = 1_000
SEED = 42

BLOCK = 4096
HEADER = 16
ENVELOPE = 16
CAPACITY = 64 * 1024 * 1024  # must match the (:backing, ..., 67108864, :stop) links in dangerous_linear_regression.silica
SCHEMA = 1                   # the schema version the program accepts
ETF_FORMAT_ID = 1


def crc32c_table():
    table = []
    for n in range(256):
        c = n
        for _ in range(8):
            c = (c >> 1) ^ 0x82F63B78 if c & 1 else c >> 1
        table.append(c)
    return table


CRC_TABLE = crc32c_table()


def crc32c(data):
    c = 0xFFFFFFFF
    t = CRC_TABLE
    for b in data:
        c = t[(c ^ b) & 0xFF] ^ (c >> 8)
    return c ^ 0xFFFFFFFF


def block_header(first_seq):
    body = struct.pack(">QI", first_seq, 1)
    return body + struct.pack(">I", crc32c(body))


def envelope(seq, payload):
    head = struct.pack(">IQ", len(payload), seq)
    return head + struct.pack(">I", crc32c(head + payload)) + payload


def stored_line(line):
    value = bytes([131, 109]) + struct.pack(">I", len(line)) + line   # encode((:etf), line)
    record = bytes([ETF_FORMAT_ID]) + struct.pack(">H", SCHEMA) + value  # wireframe@record(:etf, SCHEMA, ...)
    return struct.pack(">HH", 0, 0x8000) + record                       # wireframe@frame(..., :storage), one segment


def generate_csv(path):
    rng = random.Random(SEED)
    with open(path, "w") as f:
        f.write("hours_studied,exam_score\n")
        for _ in range(ROWS):
            x = rng.uniform(0.0, 10.0)
            y = 6.0 * x + 45.0 + rng.gauss(0.0, 3.0)
            f.write(f"{x:.2f},{y:.2f}\n")
    print(f"generated {ROWS} rows in {os.path.relpath(path)}")


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    if len(sys.argv) > 1:
        csv_path = sys.argv[1]
    else:
        csv_path = os.path.join(here, "__ignore__data.csv")
        generate_csv(csv_path)
    out_path = os.path.join(here, "__ignore__data.sildat")

    data = bytearray(CAPACITY)
    block, pos, seq = 0, 0, 0
    with open(csv_path, "rb") as f:
        for raw in f:
            line = raw.rstrip(b"\r\n")
            if not line.strip():
                continue
            rec = envelope(seq, stored_line(line))
            if HEADER + len(rec) > BLOCK:
                sys.exit(f"csv_to_sildat: line {seq + 1} is too long for one record")
            if pos == 0 or pos + len(rec) > BLOCK:
                if pos != 0:
                    block += 1
                if (block + 1) * BLOCK > CAPACITY:
                    sys.exit(f"csv_to_sildat: {csv_path} does not fit in {CAPACITY} bytes; raise CAPACITY here and in the .silica links")
                data[block * BLOCK:block * BLOCK + HEADER] = block_header(seq)
                pos = HEADER
            start = block * BLOCK + pos
            data[start:start + len(rec)] = rec
            pos += len(rec)
            seq += 1

    with open(out_path, "wb") as f:
        f.write(data)
    print(f"wrote {seq} records in {block + 1} blocks to {os.path.relpath(out_path)}")


if __name__ == "__main__":
    main()
