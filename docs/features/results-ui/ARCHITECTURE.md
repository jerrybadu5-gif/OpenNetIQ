# Architecture: results UI (#22)

```
domain/entities/test_server.dart        TestServer, TestServerKind, presets, presetFor()
core/theme/chart_legend.dart            ChartLegend (shared)
features/speed_test/
  application/speed_test_providers.dart testServerPresetsProvider (+ existing history)
  presentation/speed_test_screen.dart   ServerCard (presets), SpeedHistoryCard
  presentation/throughput_chart.dart    ThroughputChart (fl_chart LineChart)
features/latency_test/presentation/
  latency_test_screen.dart              live RttChart, LatencyHistoryCard
  rtt_chart.dart                        RttChart (fl_chart LineChart)
```

- No new storage, channel or native code. History reads the existing Drift
  streams (`watchSpeedTests`, `watchLatencyTests`).
- Presets live in the domain layer and reach the UI through a provider, so
  tests and future remote server lists can override them.
- Charts are stateless; they take plain lists from controller state or stored
  records (`raw_rtts_ms`).
