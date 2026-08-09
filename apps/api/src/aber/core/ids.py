"""UUIDv7 generation (RFC 9562).

Every primary key in the system is a UUIDv7. Two properties matter:

1. **Client-generatable.** The Flutter app creates ids offline and the server
   accepts them, so there is no temp-id-to-real-id rewriting anywhere. That
   single decision removes the nastiest class of offline-sync bugs.
2. **Time-ordered.** The leading 48 bits are a millisecond timestamp, so index
   locality on insert is close to a bigserial's, unlike UUIDv4.

Implemented locally rather than pulled from a library: it is ~15 lines, removes
a dependency from the hot path, and lets us test the ordering guarantee directly.
"""

from __future__ import annotations

import os
import time
from uuid import UUID


def uuid7(*, timestamp_ms: int | None = None) -> UUID:
    """Return a new UUIDv7.

    Layout: 48-bit big-endian unix-ms | version(4) | rand_a(12) | variant(2) | rand_b(62)
    """
    ms = timestamp_ms if timestamp_ms is not None else time.time_ns() // 1_000_000
    rand = os.urandom(10)

    value = ms << 80
    value |= 0x7 << 76  # version 7
    value |= (int.from_bytes(rand[:2], "big") & 0x0FFF) << 64  # rand_a
    value |= 0b10 << 62  # RFC 4122 variant
    value |= int.from_bytes(rand[2:], "big") & ((1 << 62) - 1)  # rand_b
    return UUID(int=value)


def uuid7_timestamp_ms(value: UUID) -> int:
    """Extract the embedded millisecond timestamp from a UUIDv7."""
    if value.version != 7:
        raise ValueError(f"expected a UUIDv7, got version {value.version}")
    return value.int >> 80
