"""UUIDv7 guarantees.

The offline sync design assumes client-generated ids are unique and roughly
time-ordered. Both properties are tested here rather than assumed.
"""

from __future__ import annotations

import time

import pytest

from aber.core.ids import uuid7, uuid7_timestamp_ms


def test_version_and_variant_are_rfc_compliant() -> None:
    u = uuid7()
    assert u.version == 7
    assert (u.int >> 62) & 0b11 == 0b10


def test_ids_are_unique_under_tight_looping() -> None:
    ids = {uuid7() for _ in range(50_000)}
    assert len(ids) == 50_000


def test_ids_generated_over_time_sort_chronologically() -> None:
    first = uuid7()
    time.sleep(0.005)
    second = uuid7()
    assert first < second
    assert str(first) < str(second), "lexical order must match creation order too"


def test_embedded_timestamp_round_trips() -> None:
    ms = 1_767_225_600_000  # 2026-01-01T00:00:00Z
    assert uuid7_timestamp_ms(uuid7(timestamp_ms=ms)) == ms


def test_embedded_timestamp_tracks_wall_clock() -> None:
    before = time.time_ns() // 1_000_000
    extracted = uuid7_timestamp_ms(uuid7())
    after = time.time_ns() // 1_000_000
    assert before <= extracted <= after


def test_rejects_non_v7_input() -> None:
    import uuid as stdlib_uuid

    with pytest.raises(ValueError, match="expected a UUIDv7"):
        uuid7_timestamp_ms(stdlib_uuid.uuid4())
