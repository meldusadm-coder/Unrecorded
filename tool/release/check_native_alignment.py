#!/usr/bin/env python3
"""Check all bundled 64-bit ELF LOAD segments for 16 KB page compatibility."""
import struct
import sys
import zipfile


def check_elf(data):
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        raise ValueError("expected a little-endian ELF64 library")
    phoff = struct.unpack_from("<Q", data, 32)[0]
    entsize, count = struct.unpack_from("<HH", data, 54)
    if entsize < 56 or not count:
        raise ValueError("missing ELF program headers")
    loads = 0
    for index in range(count):
        header = struct.unpack_from("<IIQQQQQQ", data, phoff + index * entsize)
        kind, _, offset, address, _, _, _, alignment = header
        if kind == 1:
            loads += 1
            if alignment < 16384 or alignment & (alignment - 1) or (address - offset) % 16384:
                raise ValueError("LOAD segment is not 16 KB aligned")
    if not loads:
        raise ValueError("no LOAD segments")


def main(archive):
    checked = 0
    with zipfile.ZipFile(archive) as bundle:
        for name in bundle.namelist():
            if name.endswith(".so") and any(f"/lib/{abi}/" in "/" + name for abi in ("arm64-v8a", "x86_64")):
                try:
                    check_elf(bundle.read(name))
                except (ValueError, struct.error, IndexError) as error:
                    raise ValueError(f"{name}: {error}") from error
                checked += 1
                print(f"16 KB ELF alignment verified: {name}")
    if not checked:
        raise ValueError("No 64-bit libraries found; wrong or incomplete release artifact")


if __name__ == "__main__":
    main(sys.argv[1])
