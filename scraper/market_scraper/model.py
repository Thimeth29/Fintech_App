"""One price row, shaped like public.market_prices."""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone

KINDS = {"stock", "gold", "forex", "fd_rate", "tbill_yield", "tbond_yield"}


@dataclass
class Price:
    symbol: str          # same key space as the app: JKH.N, USDLKR, GOLD24K, FD|Bank|12, TBILL_91
    kind: str
    name: str
    price: float         # LKR, or % p.a. for *_rate / *_yield
    unit: str
    source: str
    as_of: datetime      # when the source published it
    source_url: str | None = None
    change_pct: float | None = None
    history: dict[str, float] = field(default_factory=dict)  # ISO date -> close, for backfill

    def __post_init__(self) -> None:
        if self.kind not in KINDS:
            raise ValueError(f"unknown kind {self.kind}")
        if not (self.price > 0):
            raise ValueError(f"{self.symbol}: price must be positive")
        if self.as_of.tzinfo is None:
            self.as_of = self.as_of.replace(tzinfo=timezone.utc)

    def row(self) -> dict:
        return {
            "symbol": self.symbol,
            "kind": self.kind,
            "name": self.name,
            "price": round(self.price, 6),
            "unit": self.unit,
            "change_pct": None if self.change_pct is None else round(self.change_pct, 4),
            "source": self.source,
            "source_url": self.source_url,
            "as_of": self.as_of.isoformat(),
        }
