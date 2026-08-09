"""Time. The server clock is authoritative for every business timestamp.

Device clocks are recorded separately (as ``device_recorded_at``) for forensics,
never used to order events — an agent's phone can be wrong by hours, and
attendance records are payroll input.

Injectable so tests can freeze time without monkeypatching ``datetime``.
"""

from __future__ import annotations

from datetime import UTC, datetime, tzinfo
from zoneinfo import ZoneInfo

# Gulf Standard Time. Used for business-day boundaries (attendance days, the
# nightly rollup at 02:00, monthly commission periods) — never for storage,
# which is always UTC.
GST = ZoneInfo("Asia/Dubai")


class Clock:
    def now(self) -> datetime:
        return datetime.now(UTC)

    def today(self, tz: tzinfo = GST) -> datetime:
        return self.now().astimezone(tz)


class FrozenClock(Clock):
    def __init__(self, at: datetime) -> None:
        if at.tzinfo is None:
            raise ValueError("FrozenClock requires a timezone-aware datetime")
        self._at = at

    def now(self) -> datetime:
        return self._at


_clock = Clock()


def utcnow() -> datetime:
    return _clock.now()


def business_date(moment: datetime | None = None) -> datetime:
    """The GST calendar day a UTC instant belongs to."""
    return (moment or utcnow()).astimezone(GST)
