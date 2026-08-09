"""Money handling. Decimal only — floats are banned system-wide.

A rounding error in a commission split is real money owed to a real agent, so
the rules here are deliberately rigid:

* every amount is a ``Decimal`` quantized to 2 dp (AED fils);
* rounding is ROUND_HALF_UP, applied once, at the end of a calculation;
* splitting an amount always returns parts that sum **exactly** to the original —
  the rounding remainder goes to a designated party rather than evaporating.

``allocate`` is the function the commission engine uses for splits, and its
sum-preservation property is asserted by a Hypothesis test.
"""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal, localcontext

CENTS = Decimal("0.01")
ZERO = Decimal("0.00")
DEFAULT_CURRENCY = "AED"


def to_money(value: Decimal | int | str) -> Decimal:
    """Coerce to a 2 dp Decimal. Floats are rejected, not silently converted."""
    if isinstance(value, float):
        raise TypeError("float is not accepted for monetary values — pass Decimal, int or str")
    return Decimal(value).quantize(CENTS, rounding=ROUND_HALF_UP)


def percent_of(amount: Decimal, percent: Decimal) -> Decimal:
    """`percent` is expressed as a percentage, so 2.5 means 2.5%."""
    with localcontext() as ctx:
        ctx.prec = 28
        return to_money(amount * percent / Decimal(100))


def allocate(amount: Decimal, weights: list[Decimal]) -> list[Decimal]:
    """Split `amount` across `weights`, preserving the total exactly.

    Each part is rounded down to the cent, then the leftover cents are handed
    out one at a time to the largest-weight parts. The result always satisfies
    ``sum(result) == amount``.
    """
    if not weights:
        raise ValueError("weights must not be empty")
    if any(w < 0 for w in weights):
        raise ValueError("weights must be non-negative")

    total_weight = sum(weights, Decimal(0))
    if total_weight == 0:
        raise ValueError("weights must not sum to zero")

    amount = to_money(amount)

    with localcontext() as ctx:
        ctx.prec = 28
        raw = [amount * w / total_weight for w in weights]

    parts = [r.quantize(CENTS, rounding="ROUND_DOWN") for r in raw]
    remainder = amount - sum(parts, ZERO)

    # Hand out the leftover cents largest-fractional-part first, tie-broken by
    # index so the allocation is deterministic and order-independent tests hold.
    steps = int((remainder / CENTS).to_integral_value())
    order = sorted(range(len(parts)), key=lambda i: (-(raw[i] - parts[i]), i))
    for k in range(steps):
        parts[order[k % len(parts)]] += CENTS

    return parts


def sum_money(values: list[Decimal]) -> Decimal:
    return to_money(sum(values, ZERO))
