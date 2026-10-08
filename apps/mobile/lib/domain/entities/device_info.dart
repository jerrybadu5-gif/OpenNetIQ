/// Device that produced the measurements (`devices` table).
/// Never contains IMEI, IMSI, MSISDN or other subscriber identifiers.
class DeviceInfo {
  const DeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.apiLevel,
    required this.appVersion,
    this.chipset,
  });

  final String manufacturer;
  final String model;
  final String androidVersion;
  final int apiLevel;
  final String? chipset;
  final String appVersion;
}
