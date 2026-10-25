import 'package:opennetiq_mobile/domain/entities/test_status.dart';

export 'package:opennetiq_mobile/domain/entities/test_status.dart';

/// Voice and SMS sequences (issue #30, ADR-022, methodology §6c).
enum VoiceSmsKind {
  call('call', 'Voice call'),
  sms('sms', 'SMS');

  const VoiceSmsKind(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static VoiceSmsKind? fromWire(String? value) {
    for (final k in values) {
      if (k.wireValue == value) return k;
    }
    return null;
  }
}

/// A configured test line. The number stays in local settings; results
/// keep only [masked] (last two digits).
class PhoneTarget {
  const PhoneTarget(this.name, this.number, {this.loopback = false});

  factory PhoneTarget.fromJson(Map<String, Object?> j) => PhoneTarget(
    j['name']! as String,
    j['number']! as String,
    loopback: j['loopback'] as bool? ?? false,
  );

  final String name;
  final String number;

  /// The number belongs to this phone (SMS sent to itself).
  final bool loopback;

  static final RegExp _valid = RegExp(r'^\+?[0-9*#]{3,20}$');

  static String normalise(String n) => n.replaceAll(RegExp(r'[\s\-()]'), '');

  static bool isValidNumber(String n) => _valid.hasMatch(normalise(n));

  static String maskNumber(String n) {
    final d = normalise(n);
    return d.length <= 2 ? '••' : '••${d.substring(d.length - 2)}';
  }

  String get masked => maskNumber(number);

  Map<String, Object?> toJson() => {
    'name': name,
    'number': number,
    if (loopback) 'loopback': true,
  };

  /// One per line: `Name | number` or `Name | number | self`.
  static String toLines(List<PhoneTarget> list) => [
    for (final t in list)
      '${t.name} | ${t.number}${t.loopback ? ' | self' : ''}',
  ].join('\n');

  static (List<PhoneTarget>, List<String>) parseLines(String text) {
    final targets = <PhoneTarget>[];
    final errors = <String>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = [for (final p in line.split('|')) p.trim()];
      final number = parts.length == 1 ? parts[0] : parts[1];
      if (!isValidNumber(number)) {
        errors.add('Line ${i + 1}: not a phone number');
        continue;
      }
      final name = parts.length == 1 || parts[0].isEmpty
          ? 'Line ${maskNumber(number)}'
          : parts[0];
      final self = parts.length > 2 && parts[2].toLowerCase() == 'self';
      targets.add(PhoneTarget(name, normalise(number), loopback: self));
    }
    return (targets, errors);
  }
}

/// Call timing defaults follow the NICTA Telecommunications QoS Rule 2022,
/// Schedule 1 guideline (9): setup 20 s, holding 120 s, interval 30 s
/// (total call window 170 s).
class VoiceSmsSettings {
  const VoiceSmsSettings({
    this.callTargets = const [],
    this.smsTargets = const [],
    this.setupTimeoutSeconds = 20,
    this.holdSeconds = 120,
    this.intervalSeconds = 30,
    this.smsTimeoutSeconds = 60,
  });

  factory VoiceSmsSettings.fromJson(Map<String, Object?> j) {
    List<PhoneTarget> list(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map) PhoneTarget.fromJson(e.cast<String, Object?>()),
    ];
    return VoiceSmsSettings(
      callTargets: list(j['call_targets']),
      smsTargets: list(j['sms_targets']),
      setupTimeoutSeconds: (j['setup_timeout_s'] as num?)?.toInt() ?? 20,
      holdSeconds: (j['hold_s'] as num?)?.toInt() ?? 120,
      intervalSeconds: (j['interval_s'] as num?)?.toInt() ?? 30,
      smsTimeoutSeconds: (j['sms_timeout_s'] as num?)?.toInt() ?? 60,
    );
  }

  final List<PhoneTarget> callTargets;
  final List<PhoneTarget> smsTargets;

  /// A call not set up within this time is unsuccessful.
  final int setupTimeoutSeconds;

  /// Holding time after setup. The call is released setup timeout + hold
  /// after dialling, so a call set up in time is held at least this long.
  final int holdSeconds;

  /// Idle time between consecutive calls.
  final int intervalSeconds;

  /// Dialling to release.
  int get callWindowSeconds => setupTimeoutSeconds + holdSeconds;

  /// One call cycle including the interval (NICTA: 170 s).
  int get totalCallWindowSeconds => callWindowSeconds + intervalSeconds;

  /// Wait for delivery report / arrival.
  final int smsTimeoutSeconds;

  List<PhoneTarget> targets(VoiceSmsKind k) =>
      k == VoiceSmsKind.call ? callTargets : smsTargets;

  VoiceSmsSettings copyWith({
    List<PhoneTarget>? callTargets,
    List<PhoneTarget>? smsTargets,
    int? setupTimeoutSeconds,
    int? holdSeconds,
    int? intervalSeconds,
    int? smsTimeoutSeconds,
  }) => VoiceSmsSettings(
    callTargets: callTargets ?? this.callTargets,
    smsTargets: smsTargets ?? this.smsTargets,
    setupTimeoutSeconds: setupTimeoutSeconds ?? this.setupTimeoutSeconds,
    holdSeconds: holdSeconds ?? this.holdSeconds,
    intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    smsTimeoutSeconds: smsTimeoutSeconds ?? this.smsTimeoutSeconds,
  );

  Map<String, Object?> toJson() => {
    'version': 2,
    'call_targets': [for (final t in callTargets) t.toJson()],
    'sms_targets': [for (final t in smsTargets) t.toJson()],
    'setup_timeout_s': setupTimeoutSeconds,
    'hold_s': holdSeconds,
    'interval_s': intervalSeconds,
    'sms_timeout_s': smsTimeoutSeconds,
  };
}

/// One call or SMS result. Unavailable values are null.
class VoiceSmsResult {
  const VoiceSmsResult({
    required this.kind,
    required this.label,
    required this.targetMasked,
    required this.status,
    required this.outcome,
    this.error,
    this.windowS,
    this.callMs,
    this.setupMs,
    this.connectedS,
    this.dropped,
    this.voiceRat,
    this.loopback,
    this.sendMs,
    this.deliveryMs,
    this.receiveMs,
  });

  final VoiceSmsKind kind;
  final String label;
  final String targetMasked;
  final TestStatus status;

  /// call: completed, dropped, setup_timeout, no_answer, rejected,
  /// not_placed, unknown, ended_early. sms: received, delivered, not_received, no_report,
  /// delivery_failed, not_sent.
  final String outcome;
  final String? error;
  final int? windowS;
  final double? callMs;
  final double? setupMs;
  final int? connectedS;
  final bool? dropped;

  /// Voice technology during the call (GSM, UMTS, VoLTE, VoNR; `A>B` on a
  /// change such as SRVCC or CS fallback).
  final String? voiceRat;
  final bool? loopback;
  final double? sendMs;
  final double? deliveryMs;
  final double? receiveMs;

  /// Call set up within the setup timeout (NICTA: not a failed attempt).
  bool get setupSuccess => outcome == 'completed' || outcome == 'dropped';

  static String _s(double? ms) =>
      ms == null ? '-' : '${(ms / 1000).toStringAsFixed(1)} s';

  String get summary => switch (kind) {
    VoiceSmsKind.call => [
      outcome.replaceAll('_', ' '),
      ?voiceRat,
      if (setupMs != null) 'setup ${_s(setupMs)}',
      if (connectedS != null && connectedS! > 0) 'connected $connectedS s',
    ].join(' · '),
    VoiceSmsKind.sms => [
      outcome.replaceAll('_', ' '),
      if (sendMs != null) 'sent ${_s(sendMs)}',
      if (deliveryMs != null) 'delivered ${_s(deliveryMs)}',
      if (receiveMs != null) 'received ${_s(receiveMs)}',
    ].join(' · '),
  };
}

class VoiceSmsRecord {
  const VoiceSmsRecord({
    required this.id,
    required this.timestamp,
    required this.methodologyVersion,
    required this.result,
    this.sessionId,
    this.measurementId,
  });

  final String id;
  final DateTime timestamp;
  final String methodologyVersion;
  final VoiceSmsResult result;
  final String? sessionId;
  final String? measurementId;
}

/// Android permissions of the voice and SMS tests.
class VoiceSmsPermissions {
  const VoiceSmsPermissions({
    this.call = false,
    this.endCall = false,
    this.callLog = false,
    this.sendSms = false,
    this.receiveSms = false,
    this.hasTelephony = true,
  });

  factory VoiceSmsPermissions.fromMap(Map<Object?, Object?> m) =>
      VoiceSmsPermissions(
        call: m['call'] == true,
        endCall: m['end_call'] == true,
        callLog: m['call_log'] == true,
        sendSms: m['send_sms'] == true,
        receiveSms: m['receive_sms'] == true,
        hasTelephony: m['has_telephony'] != false,
      );

  final bool call;
  final bool endCall;
  final bool callLog;
  final bool sendSms;
  final bool receiveSms;
  final bool hasTelephony;

  bool get all => call && endCall && callLog && sendSms && receiveSms;
}
