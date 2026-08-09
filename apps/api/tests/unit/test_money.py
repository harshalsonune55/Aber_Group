"""Money invariants.

The commission engine's correctness rests on ``allocate`` never losing or
inventing a fil. These tests are the guard on that, and the property-based ones
are deliberately aggressive because the failure mode is silently underpaying an
agent by a cent per deal for a year.
"""

from __future__ import annotations

from decimal import Decimal

import pytest
from hypothesis import given
from hypothesis import settings as hyp_settings
from hypothesis import strategies as st

from aber.core.money import ZERO, allocate, percent_of, sum_money, to_money


class TestToMoney:
    def test_quantizes_to_two_places(self) -> None:
        assert to_money(Decimal("10.005")) == Decimal("10.01")
        assert to_money(Decimal("10.004")) == Decimal("10.00")

    def test_accepts_int_and_str(self) -> None:
        assert to_money(5) == Decimal("5.00")
        assert to_money("1234.5") == Decimal("1234.50")

    def test_rejects_float(self) -> None:
        # Floats must never reach a monetary column; catching it at the boundary
        # is the only reliable place.
        with pytest.raises(TypeError, match="float is not accepted"):
            to_money(10.5)  # type: ignore[arg-type]


class TestPercentOf:
    def test_basic(self) -> None:
        assert percent_of(Decimal("1000000"), Decimal("2")) == Decimal("20000.00")

    def test_fractional_percent_rounds_half_up(self) -> None:
        # A typical UAE agency fee of 2.5% on an odd sale price.
        assert percent_of(Decimal("1234567.89"), Decimal("2.5")) == Decimal("30864.20")


class TestAllocate:
    def test_even_split(self) -> None:
        assert allocate(Decimal("100.00"), [Decimal(1), Decimal(1)]) == [
            Decimal("50.00"),
            Decimal("50.00"),
        ]

    def test_indivisible_amount_preserves_total(self) -> None:
        parts = allocate(Decimal("100.00"), [Decimal(1), Decimal(1), Decimal(1)])
        assert sum(parts) == Decimal("100.00")
        assert sorted(parts) == [Decimal("33.33"), Decimal("33.33"), Decimal("33.34")]

    def test_weighted_split(self) -> None:
        # A realistic split: closing agent 50%, listing agent 30%, manager 20%.
        parts = allocate(Decimal("30000.00"), [Decimal(50), Decimal(30), Decimal(20)])
        assert parts == [Decimal("15000.00"), Decimal("9000.00"), Decimal("6000.00")]
        assert sum(parts) == Decimal("30000.00")

    def test_zero_weight_participant_gets_nothing(self) -> None:
        parts = allocate(Decimal("100.00"), [Decimal(1), Decimal(0)])
        assert parts[1] == ZERO
        assert sum(parts) == Decimal("100.00")

    def test_rejects_empty_weights(self) -> None:
        with pytest.raises(ValueError, match="must not be empty"):
            allocate(Decimal("100.00"), [])

    def test_rejects_all_zero_weights(self) -> None:
        with pytest.raises(ValueError, match="must not sum to zero"):
            allocate(Decimal("100.00"), [Decimal(0), Decimal(0)])

    def test_rejects_negative_weights(self) -> None:
        with pytest.raises(ValueError, match="non-negative"):
            allocate(Decimal("100.00"), [Decimal(-1), Decimal(2)])

    @hyp_settings(max_examples=400)
    @given(
        amount=st.decimals(
            min_value=Decimal("0.01"),
            max_value=Decimal("100000000"),
            places=2,
            allow_nan=False,
            allow_infinity=False,
        ),
        weights=st.lists(
            st.decimals(
                min_value=Decimal("0"),
                max_value=Decimal("1000"),
                places=2,
                allow_nan=False,
                allow_infinity=False,
            ),
            min_size=1,
            max_size=6,
        ),
    )
    def test_allocation_always_sums_to_the_original(
        self, amount: Decimal, weights: list[Decimal]
    ) -> None:
        if sum(weights) == 0:
            return
        parts = allocate(amount, weights)
        assert sum(parts) == amount, "allocation must never lose or invent money"
        assert all(p >= ZERO for p in parts), "no split may be negative"
        assert len(parts) == len(weights)


class TestSumMoney:
    def test_sums_and_quantizes(self) -> None:
        assert sum_money([Decimal("1.005"), Decimal("2.005")]) == Decimal("3.01")

    def test_empty_is_zero(self) -> None:
        assert sum_money([]) == ZERO
