# Signal Monitor - Architecture

```
SignalMonitorScreen (features/signal_monitor/presentation)
  ref.watch(radioPermissionsProvider)   AsyncNotifier: get / request permissions
  ref.watch(radioSnapshotProvider)      StreamProvider (auto-dispose, no retry)
  ref.watch(signalHistoryProvider)      Notifier: last 60 levels for the chart
        |
RadioRepository (domain interface)  <-  PlatformRadioRepository (data)
        |                                  RadioSnapshotMapper + ChannelReader (strict)
MethodChannel org.opennetiq/measurement    EventChannel org.opennetiq/radio
        |                                  |
MeasurementBridge (Kotlin)  ->  RadioCollector
                                  requestCellInfoUpdate every interval (main looper)
                                  TelephonyCallback / PhoneStateListener: display-info override
                                  CellInfoAdapter (Android types) -> CellObservations (pure)
                                  NetworkTypeResolver (pure), Plmn, DataStates
```

## Design points
| Topic | Decision |
|---|---|
| Fresh data | `requestCellInfoUpdate` per tick; on modem error fall back to cached `getAllCellInfo` and flag `CACHED` |
| Validation | Kotlin is the validator: ranges from MEASUREMENT-METHODOLOGY section 2, UNAVAILABLE/out-of-range -> null + quality flag, never clamped |
| Testability | All mapping in pure Kotlin objects (`CellObservations`, `NetworkTypeResolver`, `CellIdentityMath`) with no Android types; Android adapter is a thin extraction layer |
| 5G NSA | Data network type LTE + display override NR_NSA/NR_ADVANCED -> `NR_NSA`; NR data network type -> `NR_SA` |
| Battery | Snapshot stream auto-disposes when the screen closes; native collector stops on stream cancel |
| Threading | Collector, callbacks and event sink all on the main thread |
| Contract | Hand-written typed channels (ADR-013), snake_case keys = data-dictionary columns |

## Files
- Kotlin: `android/app/src/main/kotlin/org/opennetiq/measurement/{radio,bridge}/`
- Dart: `lib/domain/{entities,value_objects,repositories,errors}/`, `lib/data/{mappers,repositories}/`, `lib/platform/measurement_channels.dart`, `lib/features/signal_monitor/`
