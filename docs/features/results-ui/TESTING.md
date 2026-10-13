# Testing: results UI (#22)

## Automated
- `test/domain/test_server_test.dart`: preset order, URL shape, matching.
- `test/features/speed_test_screen_test.dart`: preset menu saves the URL,
  public-server note, curve shown only with samples, history row opens the
  result, empty history.
- `test/features/latency_test_screen_test.dart`: live RTT chart, charts in
  result cards (including all-lost), history row opens the result.

## On device
1. Speed test → list icon in the server field → pick a preset; the note
   appears for public servers. Pick your local server again.
2. Run a speed test: the curve grows during download, then upload.
3. The result appears under **History**; tap it to open the details.
4. Latency test → Start: the RTT chart fills per protocol; each result card
   has its chart; rows appear under **History**.
