# Cell scan and estimated sites (issue #27)

- **Home → Cell scan**: every cell seen on all drives, grouped by RAT, band
  and channel (EARFCN / NR-ARFCN / UARFCN / ARFCN): PCI, cell ID, eNB/gNB,
  best and mean level, serving and neighbour counts, first and last seen.
- **Session → Cell scan**: the same for one session.
- **Map**: estimated sites (tower icon), uncertainty circle, short sector
  lines; tap a sample on the track to draw the line to its serving site;
  *Serving lines* shows lines for the whole track (thinned to 300).
- **Export → KML** (and *All formats*): Google Earth file with the track
  coloured by level class, sample points (hidden by default, time-stamped
  for the time slider) and the estimated sites of that session.

Positions are estimated from your drives (method in ADR-019 and
MEASUREMENT-METHODOLOGY.md §6a), never surveyed. Each site shows its method
(*Timing advance* or *Strongest samples*) and an uncertainty radius. Drive
around sites, not just past them, for better positions.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md).
