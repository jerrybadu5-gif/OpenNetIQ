/// Campaign tags of a session (spec v3 M15): where it was measured, for
/// reporting per region and area class (NICTA QoS Rule 2022 s.10(2)).
library;

enum AreaClass {
  urban('urban', 'Urban'),
  semiUrban('semi_urban', 'Semi-urban'),
  rural('rural', 'Rural');

  const AreaClass(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static AreaClass? fromWire(String? value) {
    for (final a in values) {
      if (a.wireValue == value) return a;
    }
    return null;
  }
}

/// PNG's four regions, offered as suggestions (free text is allowed).
const List<String> pngRegions = ['Southern', 'Highlands', 'Momase', 'Islands'];

class CampaignTags {
  const CampaignTags({this.region, this.areaClass, this.location});

  factory CampaignTags.fromJson(Map<String, Object?> j) => CampaignTags(
    region: _clean(j['region'] as String?),
    areaClass: AreaClass.fromWire(j['area_class'] as String?),
    location: _clean(j['location'] as String?),
  );

  static const none = CampaignTags();

  final String? region;
  final AreaClass? areaClass;

  /// Location name, e.g. "Waigani" (a place, never a person).
  final String? location;

  static String? _clean(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Trimmed, empty strings as null.
  CampaignTags normalised() => CampaignTags(
    region: _clean(region),
    areaClass: areaClass,
    location: _clean(location),
  );

  bool get isEmpty => region == null && areaClass == null && location == null;

  /// e.g. "Waigani · Southern · Urban"; empty when untagged.
  String get summary => [?location, ?region, ?areaClass?.label].join(' · ');

  Map<String, Object?> toJson() => {
    'version': 1,
    'region': ?region,
    'area_class': ?areaClass?.wireValue,
    'location': ?location,
  };

  @override
  bool operator ==(Object other) =>
      other is CampaignTags &&
      other.region == region &&
      other.areaClass == areaClass &&
      other.location == location;

  @override
  int get hashCode => Object.hash(region, areaClass, location);
}
