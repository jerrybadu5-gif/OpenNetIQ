# ADR-019: Cell sites estimated from drive data

## Context
G-NetTrack Pro draws sites and serving lines from an operator cell file.
NICTA has no operator site lists, so the cell layer must come from OpenNetIQ
measurements alone, "as accurate as possible" (spec v0.1.0-extension).

## Decision
- Estimate one position per eNB/gNB from all its cells and all sessions.
- Prefer a least-squares fit to LTE timing-advance ranges (78.12 m per
  step), reject geometrically ambiguous fits (straight roads), fall back to
  a level-weighted centroid of the strongest samples with a wide uncertainty.
- Estimate sector azimuths from where each cell is strongest.
- Always show method and uncertainty radius; label every output "estimated".
- Pure Dart domain service (`CellLayerBuilder`, `SiteEstimator`), computed on
  demand from stored observations; no new tables.

## Consequences
- Accuracy depends on TA availability (chipset) and route geometry; drives
  around a site (loops, crossings) give the best results.
- Positions change as more drives are recorded (not stored, recomputed).
- Operator site-file import can be added later and would replace estimates
  where available.
