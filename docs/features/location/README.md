# Location (GNSS) Collector

Raw GNSS positions for geotagging every measurement. Closes #14.

## What it does
- `LocationManager.GPS_PROVIDER` at the measurement interval (default 1 s). No Google Play Services, no fused smoothing (ADR-006).
- Per tick: latitude, longitude, altitude, speed, bearing, horizontal and vertical accuracy, satellites used/visible, fix age.
- `gps_quality`: `GOOD` (fix age ≤ 2 s and accuracy ≤ 50 m), `POOR` (otherwise), `NONE` (no fix, fix older than 30 s, or Location switched off).
- Mock-location detection: flagged `MOCK_LOCATION`, excluded from regulatory statistics.
- Shown on the Signal Monitor screen as the **GPS** card.

## Permissions
`ACCESS_FINE_LOCATION` (already requested by the Signal Monitor). Location services must be switched on.

## Known limits
- Indoors the first fix can take minutes; the card shows satellites used/visible while searching.
- Background collection (screen off) comes with the drive-test foreground service (#17).
- Not stored yet: storage arrives with #16; samples combine the radio snapshot and the location status of the same tick.
