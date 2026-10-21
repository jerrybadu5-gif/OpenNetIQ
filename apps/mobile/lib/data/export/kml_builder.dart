import 'package:opennetiq_mobile/core/utc_time.dart';
import 'package:opennetiq_mobile/data/export/session_export_builder.dart';
import 'package:opennetiq_mobile/data/local/app_database.dart';
import 'package:opennetiq_mobile/domain/entities/cell_observation.dart';
import 'package:opennetiq_mobile/domain/entities/cell_scan.dart';
import 'package:opennetiq_mobile/domain/entities/rat.dart';
import 'package:opennetiq_mobile/domain/entities/sample_point.dart';
import 'package:opennetiq_mobile/domain/services/cell_layer_builder.dart';
import 'package:opennetiq_mobile/domain/services/sample_quality.dart';
import 'package:opennetiq_mobile/domain/services/track_segments.dart';
import 'package:opennetiq_mobile/domain/value_objects/signal_quality.dart';

/// KML 2.2 export (issue #27) for Google Earth: track coloured by level
/// class, sample points, estimated sites from this session.
class KmlBuilder {
  const KmlBuilder(this.data);

  final SessionExportData data;

  /// KML colours are aabbggrr; same palette as the app legend.
  static const Map<SignalQuality?, String> colors = {
    SignalQuality.excellent: 'ff3a8a1b',
    SignalQuality.good: 'ff1f9e5b',
    SignalQuality.fair: 'ff008ac9',
    SignalQuality.poor: 'ff0b62d9',
    SignalQuality.noService: 'ff2828c6',
    null: 'ff757575',
  };

  static String styleId(SignalQuality? q) => 'q_${q?.name ?? 'none'}';

  static String esc(Object? v) => '${v ?? ''}'
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  bool _usable(SampleRow s) =>
      s.lat != null &&
      s.lon != null &&
      !(s.qualityFlag ?? '').split('|').contains(SampleQuality.mockLocation);

  List<SamplePoint> points() => [
    for (final s in data.samples)
      if (parseUtc(s.timestamp) case final DateTime at)
        _point(s, at, ServingCells.of(data.cells[s.measurementId] ?? const [])),
  ];

  SamplePoint _point(SampleRow s, DateTime at, ServingCells cells) {
    final p = cells.primary;
    final rat = Rat.fromWire(p?.rat);
    return SamplePoint(
      timestamp: at,
      lat: _usable(s) ? s.lat : null,
      lon: _usable(s) ? s.lon : null,
      rat: rat,
      levelDbm: rat == null || p == null
          ? null
          : CellObservation.levelFor(
              rat,
              rsrpDbm: p.rsrpDbm,
              rscpDbm: p.rscpDbm,
              rssiDbm: p.rssiDbm,
            ),
      measurementId: s.measurementId,
    );
  }

  List<CellSighting> sightings() {
    final byId = {for (final s in data.samples) s.measurementId: s};
    return [
      for (final e in data.cells.entries)
        for (final c in e.value)
          if ((byId[e.key], Rat.fromWire(c.rat)) case (
            final SampleRow s?,
            final Rat rat?,
          ))
            if (parseUtc(s.timestamp) case final DateTime at)
              CellSighting(
                measurementId: s.measurementId,
                timestamp: at,
                isServing: c.isServing,
                rat: rat,
                lat: _usable(s) ? s.lat : null,
                lon: _usable(s) ? s.lon : null,
                goodFix: s.gpsQuality == 'GOOD',
                mcc: c.mcc,
                mnc: c.mnc,
                lacTac: c.lacTac,
                cellId: c.cellId,
                enbId: c.enbId,
                gnbId: c.gnbId,
                pci: c.pciPscBsic,
                arfcn: c.arfcn,
                band: c.band,
                levelDbm: CellObservation.levelFor(
                  rat,
                  rsrpDbm: c.rsrpDbm,
                  rscpDbm: c.rscpDbm,
                  rssiDbm: c.rssiDbm,
                ),
                timingAdvance: c.timingAdvance,
              ),
    ];
  }

  String build() {
    final s = data.session;
    final pts = points();
    final layer = CellLayerBuilder.build(sightings());
    final b = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<kml xmlns="http://www.opengis.net/kml/2.2">')
      ..writeln('<Document>')
      ..writeln('<name>${esc(s.name)}</name>')
      ..writeln(
        '<description>OpenNetIQ session ${esc(s.sessionId)}, '
        'methodology ${esc(s.methodologyVersion)}. Site positions are '
        'estimated from drive data.</description>',
      );
    for (final e in colors.entries) {
      b.writeln(
        '<Style id="${styleId(e.key)}"><LineStyle><color>${e.value}</color>'
        '<width>4</width></LineStyle><IconStyle><color>${e.value}</color>'
        '<scale>0.5</scale><Icon><href>'
        'http://maps.google.com/mapfiles/kml/shapes/shaded_dot.png'
        '</href></Icon></IconStyle></Style>',
      );
    }
    b.writeln(
      '<Style id="site"><IconStyle><scale>1.1</scale><Icon><href>'
      'http://maps.google.com/mapfiles/kml/shapes/target.png</href></Icon>'
      '</IconStyle></Style>',
    );

    b.writeln('<Folder><name>Track</name>');
    for (final seg in TrackSegments.build(pts)) {
      if (seg.points.length < 2) continue;
      b.writeln(
        '<Placemark><name>${esc(seg.quality?.label ?? 'No level')}</name>'
        '<styleUrl>#${styleId(seg.quality)}</styleUrl><LineString>'
        '<tessellate>1</tessellate><coordinates>'
        '${seg.points.map((p) => '${p.lon},${p.lat},0').join(' ')}'
        '</coordinates></LineString></Placemark>',
      );
    }
    b
      ..writeln('</Folder>')
      ..writeln('<Folder><name>Samples</name><visibility>0</visibility>');
    for (final p in pts) {
      if (!p.hasPosition) continue;
      b.writeln(
        '<Placemark><visibility>0</visibility>'
        '<description>${esc(formatUtc(p.timestamp))} '
        '${esc(p.rat?.wireValue)} '
        '${p.levelDbm == null ? '' : '${p.levelDbm!.toStringAsFixed(0)} dBm'}'
        '</description><TimeStamp><when>${formatUtc(p.timestamp)}</when>'
        '</TimeStamp><styleUrl>#${styleId(p.quality)}</styleUrl>'
        '<Point><coordinates>${p.lon},${p.lat},0</coordinates></Point>'
        '</Placemark>',
      );
    }
    b
      ..writeln('</Folder>')
      ..writeln('<Folder><name>Estimated sites</name>');
    for (final site in layer.sites) {
      b.writeln(
        '<Placemark><name>${esc(site.label)}</name><styleUrl>#site</styleUrl>'
        '<description>${esc(_siteDescription(site))}</description>'
        '<Point><coordinates>${site.lon},${site.lat},0</coordinates></Point>'
        '</Placemark>',
      );
    }
    b
      ..writeln('</Folder>')
      ..writeln('</Document>')
      ..writeln('</kml>');
    return b.toString();
  }

  static String _siteDescription(EstimatedSite s) => [
    'Estimated (${s.method.label}), ±${s.uncertaintyM.round()} m, '
        '${s.samples} samples',
    for (final c in s.cells)
      c.azimuthDeg == null
          ? c.label
          : '${c.label}, azimuth ${c.azimuthDeg!.round()}°',
  ].join('\n');
}
