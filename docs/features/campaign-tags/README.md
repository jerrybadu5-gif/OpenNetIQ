# Campaign tags (spec v3 M15)

**Home → "Measurement location"** (also on the drive-test setup). Set the
**region** (suggestions: Southern, Highlands, Momase, Islands; free text
allowed), **area** (urban / semi-urban / rural) and **location name**
(e.g. Waigani). Every session created afterwards, recordings and stand-alone
tests alike, stores these values. Change them when you move to the next
location. *Clear* removes them. Session details show them.

Why: the NICTA QoS Rule 2022 s.10(2) requires results per location and
separately for urban, semi-urban and rural areas, with minimum sample counts
per location and per region. The Appendix A/B report (M16) groups by these
tags.

## Architecture
- Domain: `CampaignTags`, `AreaClass`, `pngRegions` (`domain/entities/campaign_tags.dart`).
- Application: `CampaignTagsController` (`app_settings` key `campaign.tags.v1`), `currentCampaignTags(ref)` (returns untagged on any read error, so tagging never blocks a measurement).
- Used by `RecordingController.start` and `TestContextService.link` when creating sessions.
- Storage: `sessions.region`, `sessions.area_class`, `sessions.location_name` (schema v4).
- UI: `CampaignTagsCard` / `CampaignTagsDialog` (`features/campaign/presentation`).

## API / data
- Settings JSON: `{version: 1, region?, area_class?, location?}`.
- Exports: `region`, `area_class`, `location_name` in the samples, tests, QoE and voice/SMS CSVs (after `session_type` in the samples CSV, otherwise last) and in every GeoJSON feature's properties.

## Testing
- `test/features/campaign_tags_test.dart`: normalising, JSON, controller persistence, broken settings fall back to untagged, session round trip, card edit/clear.
- `test/data/export/session_export_test.dart`: tags in the CSVs and GeoJSON.
- On device: set "Waigani · Southern · Urban", run a speed test and a short drive. Both sessions show the tags, and the exports carry them on every row.
