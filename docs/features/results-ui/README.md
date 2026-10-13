# Speed and latency results UI (issue #22)

Adds to the Speed test and Latency test screens:

- **Server presets**: list button in the server field. Order: the build-time
  OpenNetIQ server (`--dart-define=ONQ_SPEEDTEST_URL=...`) when set, then
  public LibreSpeed backends (Tokyo, Amsterdam). Picking a preset saves it.
- **Public-server note**: shown when the saved URL is a public preset. Public
  servers measure the international path and are volunteer-run; regulatory
  benchmarking needs a controlled server (`infra/test-server`, ETSI EG 202 057).
- **Throughput curve**: download and upload rate (1 s window, 100 ms
  sampling) against seconds since phase start, live and after the test.
- **RTT chart**: RTT per probe for the running protocol and inside every
  latency result card; lost probes break the line and show as red dots at 0.
- **History**: last 20 speed tests and last 30 latency rows, newest first;
  tap a row for the full result in a bottom sheet.

Curves are kept in memory only: history shows statistics, not the curve.
Storing per-sample throughput is deferred to export work (#23) if required.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md).
