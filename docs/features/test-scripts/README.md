# Test scripts (issue #28)

**Home → Test scripts.** A script is an ordered list of steps run
unattended:

- Steps available now: **Speed test**, **Latency test**, **Wait N s**.
  Web, video, app reachability and file transfer come with #29, voice call
  and SMS with #30 (shown as "coming" in the editor).
- **Repeat**: number of cycles (0 = until stopped), optionally starting each
  cycle on a fixed interval (e.g. every 2 min: the script waits for the rest
  of the interval after the steps finish).
- Presets: *Quick check* (latency, speed, once) and *Drive loop* (speed,
  latency, every 2 min until stopped).

Run a script while a **drive test is recording**: every result is linked to
the drive (position and radio at the test start) exactly like a manual test,
so it appears in the session export. Without a recording, results are saved
as stand-alone tests.

The run card shows the current cycle and step, the next cycle time and a log
(last 200 steps) with each outcome. **Stop** cancels the running test (not
saved) and ends the script; finished tests stay saved. A script keeps running
when you leave the screen; during a recording it keeps running with the
screen off.

See [ARCHITECTURE.md](ARCHITECTURE.md), [API.md](API.md), [TESTING.md](TESTING.md), ADR-020.
