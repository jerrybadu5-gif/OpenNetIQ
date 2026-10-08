import 'package:opennetiq_mobile/domain/entities/radio_permissions.dart';
import 'package:opennetiq_mobile/domain/entities/radio_snapshot.dart';

abstract interface class RadioRepository {
  /// Live radio snapshots. Errors are [RadioException]s.
  Stream<RadioSnapshot> watchSnapshots({
    Duration interval = const Duration(seconds: 1),
  });

  Future<RadioPermissions> getPermissions();

  /// Shows the Android permission dialog for any missing permission.
  Future<RadioPermissions> requestPermissions();
}
