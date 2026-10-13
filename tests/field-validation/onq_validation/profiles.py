"""Column mappings for reference tools.

Reference apps change their export columns between versions: check the
header of your file and override with `--map field=Column` when needed.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace


@dataclass(frozen=True)
class RadioProfile:
    name: str
    time: str
    time_format: str | None = None  # None = ISO 8601
    columns: dict[str, str | None] = field(default_factory=dict)  # rsrp, rsrq, sinr, pci, tech

    def with_overrides(self, overrides: dict[str, str]) -> RadioProfile:
        cols = dict(self.columns)
        time = overrides.pop("time", self.time)
        fmt = overrides.pop("time_format", self.time_format)
        cols.update(overrides)
        return replace(self, time=time, time_format=fmt, columns=cols)


PROFILES: dict[str, RadioProfile] = {
    # Columns as written by OpenNetIQ / any tool converted to this layout.
    "generic": RadioProfile(
        name="generic",
        time="timestamp",
        columns={
            "rsrp": "rsrp_dbm",
            "rsrq": "rsrq_db",
            "sinr": "sinr_db",
            "pci": "pci",
            "tech": "network_type",
        },
    ),
    # G-NetTrack Pro log (best effort; verify against your version).
    "gnettrack": RadioProfile(
        name="gnettrack",
        time="Timestamp",
        time_format="%Y.%m.%d_%H.%M.%S",
        columns={
            "rsrp": "Level",
            "rsrq": "Qual",
            "sinr": "SNR",
            "pci": None,
            "tech": "NetworkTech",
        },
    ),
}


def parse_overrides(items: list[str] | None) -> dict[str, str]:
    """`["rsrp=Level", "pci=PCI"]` -> mapping; raises ValueError on bad items."""
    result: dict[str, str] = {}
    for item in items or []:
        key, sep, value = item.partition("=")
        if not sep or not key.strip() or not value.strip():
            raise ValueError(f"bad --map item {item!r}, expected field=Column")
        result[key.strip()] = value.strip()
    return result
