/// Test scripts (issue #28): ordered steps run unattended, alone or during
/// a drive recording. JSON is the storage and exchange format (#31 shares
/// scripts between phones).
library;

enum StepType {
  speed('speed', 'Speed test', available: true),
  latency('latency', 'Latency test', available: true),
  wait('wait', 'Wait', available: true),
  web('web', 'Web browsing'),
  video('video', 'Video streaming'),
  apps('apps', 'App reachability'),
  file('file', 'File transfer'),
  call('call', 'Voice call'),
  sms('sms', 'SMS');

  const StepType(this.wireValue, this.label, {this.available = false});

  final String wireValue;
  final String label;

  /// Implemented in this build; others arrive with #29/#30.
  final bool available;

  static StepType? fromWire(String? value) {
    for (final t in values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }
}

class ScriptStep {
  const ScriptStep(this.type, {this.seconds});

  factory ScriptStep.fromJson(Map<String, Object?> json) {
    final type = StepType.fromWire(json['type'] as String?);
    if (type == null) throw FormatException('unknown step ${json['type']}');
    return ScriptStep(type, seconds: (json['seconds'] as num?)?.toInt());
  }

  final StepType type;

  /// Wait duration (wait steps).
  final int? seconds;

  String get label =>
      type == StepType.wait ? 'Wait ${seconds ?? 0} s' : type.label;

  Map<String, Object?> toJson() => {
    'type': type.wireValue,
    if (seconds != null) 'seconds': seconds,
  };
}

class TestScript {
  const TestScript({
    required this.id,
    required this.name,
    required this.steps,
    this.cycles = 1,
    this.cycleIntervalSeconds,
  });

  factory TestScript.fromJson(Map<String, Object?> json) => TestScript(
    id: json['id']! as String,
    name: json['name']! as String,
    steps: [
      for (final s in json['steps']! as List)
        ScriptStep.fromJson((s as Map).cast<String, Object?>()),
    ],
    cycles: (json['cycles'] as num?)?.toInt() ?? 1,
    cycleIntervalSeconds: (json['cycle_interval_s'] as num?)?.toInt(),
  );

  static const int formatVersion = 1;

  final String id;
  final String name;
  final List<ScriptStep> steps;

  /// Number of passes through the steps; 0 = until stopped.
  final int cycles;

  /// Start a new pass every N s (waits for the remainder); null = back to
  /// back.
  final int? cycleIntervalSeconds;

  bool get unlimited => cycles == 0;

  /// Problems that prevent running, empty when valid.
  List<String> validate() => [
    if (name.trim().isEmpty) 'Give the script a name',
    if (steps.isEmpty) 'Add at least one step',
    if (steps.every((s) => s.type == StepType.wait)) 'Add a test step',
    for (final s in steps)
      if (!s.type.available) '${s.type.label} is not available yet',
    for (final s in steps)
      if (s.type == StepType.wait && (s.seconds ?? 0) <= 0)
        'Wait steps need a duration',
    if (cycles < 0) 'Cycles cannot be negative',
    if ((cycleIntervalSeconds ?? 1) <= 0) 'Interval must be positive',
  ];

  String get summary {
    final repeat = unlimited
        ? 'until stopped'
        : cycles == 1
        ? 'once'
        : '$cycles times';
    final every = cycleIntervalSeconds == null
        ? ''
        : ', every ${cycleIntervalSeconds! ~/ 60 > 0 ? '${cycleIntervalSeconds! ~/ 60} min' : '$cycleIntervalSeconds s'}';
    return '${steps.map((s) => s.label).join(' → ')} · $repeat$every';
  }

  TestScript copyWith({
    String? name,
    List<ScriptStep>? steps,
    int? cycles,
    int? Function()? cycleIntervalSeconds,
  }) => TestScript(
    id: id,
    name: name ?? this.name,
    steps: steps ?? this.steps,
    cycles: cycles ?? this.cycles,
    cycleIntervalSeconds: cycleIntervalSeconds == null
        ? this.cycleIntervalSeconds
        : cycleIntervalSeconds(),
  );

  Map<String, Object?> toJson() => {
    'format': formatVersion,
    'id': id,
    'name': name,
    'steps': [for (final s in steps) s.toJson()],
    'cycles': cycles,
    if (cycleIntervalSeconds != null) 'cycle_interval_s': cycleIntervalSeconds,
  };
}

/// Ready-made scripts offered when none are saved.
const List<TestScript> presetScripts = [
  TestScript(
    id: 'preset-quick',
    name: 'Quick check',
    steps: [ScriptStep(StepType.latency), ScriptStep(StepType.speed)],
  ),
  TestScript(
    id: 'preset-drive',
    name: 'Drive loop',
    steps: [ScriptStep(StepType.speed), ScriptStep(StepType.latency)],
    cycles: 0,
    cycleIntervalSeconds: 120,
  ),
];
