# ADR-023: FTP throughput test and campaign tags (NICTA QoS Rule 2022)

## Context
The NICTA Telecommunications QoS Rule 2022 (traced in
`docs/standards/NICTA-QOS-RULE-2022.md`) requires mobile broadband
throughput to be measured with FTP (Schedule 2 G8): 100 MB files on LTE,
50 MB on 3G, to a server at the Port Moresby internet exchange. Signal level
is to be "recorded based on FTP download measurement samples". Reports are
per region and per urban / semi-urban / rural area (s.10(2)). OpenNetIQ had
HTTP transfers only and no location tags. Decided by the maintainer on
2026-10-25 (spec v3 M14, M15).

## Decision
- **FTP client**: Apache Commons Net 3.11.1 (Apache-2.0) in Kotlin (`FtpProbe`),
  passive binary mode, one data connection. Mean data rate = bytes × 8 /
  (RETR/STOR command → completion reply). Cut-off after a configurable
  time (default 600 s); failures keep the bytes so far. Tests run against an
  embedded Apache FtpServer (test scope, Apache-2.0).
- **FTP server**: pyftpdlib 2.0.1 (MIT) container in `infra/test-server/ftp`:
  one test account from `.env`, read-only `/download/{5..100}MB.bin`,
  writable `/upload/` with a TTL janitor, non-root, read-only rootfs,
  passive ports 30000-30009. Chosen over vsftpd/pure-ftpd (GPL, or root
  needed for chroot) to keep permissive licences and a non-root container.
- The file-transfer test keeps one kind (`file`) with a `protocol` column
  (`http`/`ftp`). The download size follows the network type at the run
  start (100/50/5 MB). The serving level is averaged over the radio
  snapshots seen during each transfer (`serving_level_dbm`, `serving_rat`).
- **Campaign tags**: `sessions.region`, `area_class`
  (`urban`/`semi_urban`/`rural`) and `location_name`, set once in the app
  (Home or drive setup) and applied to every new session. They are
  exported in every CSV row and GeoJSON feature.
- All of this is folded into schema v3, which is still unreleased.

## Consequences
- Results match the Rule's protocol and file sizes, so the method cannot be
  disputed in a compliance assessment. HTTP remains for quick checks.
- Plain FTP sends credentials unencrypted. A test-only account is
  mandatory, and the password stays in local settings and is never exported.
- 100 MB downloads take 5+ minutes at the Rule's 2.5 Mbps threshold and use
  campaign data allowances.
- Tags are only as good as what the engineer enters. The Appendix A/B
  report (M16) relies on them, so the Home card keeps them visible.
