# Location - Architecture

```
LocationCard (features/location/presentation)  <- shown inside SignalMonitorScreen
  ref.watch(locationStatusProvider)   StreamProvider, auto-dispose, starts only with precise-location permission
        |
LocationRepository (domain)  <-  PlatformLocationRepository (data) + LocationMapper (strict)
        |
EventChannel org.opennetiq/location
        |
MeasurementBridge.locationStreamHandler -> LocationCollector (Kotlin)
     requestLocationUpdates(GPS_PROVIDER, interval, 0 m, main looper)
     GnssStatus.Callback -> satellites used / visible
     ticker every interval -> LocationRules.status(...)   (pure, unit-tested)
```

| Topic | Decision |
|---|---|
| Provider | AOSP GPS only (ADR-006); raw positions, no smoothing |
| Cadence | Ticker emits at the interval even without a new fix, so fix age is visible and samples align with radio ticks |
| Validation | `LocationRules.fix`: invalid lat/lon, NaN, (0,0) and non-positive accuracy dropped; optional fields nulled, never clamped |
| Quality | `LocationRules.quality` per MEASUREMENT-METHODOLOGY section 1 |
| Integrity | `Location.isMock` (API 31) / `isFromMockProvider` (API 29-30) |
| API 29 safety | All `LocationListener` methods overridden (no default methods on Android 10) |
| Battery | Stream auto-disposes with the screen; collector stops on cancel |
