/// Route paths used with go_router.
abstract final class AppRoutes {
  static const String home = '/';
  static const String signal = '/signal';
  static const String sessions = '/sessions';
  static const String drive = '/drive';
  static const String speed = '/speed';
  static const String latency = '/latency';
  static const String privacy = '/privacy';
  static const String cells = '/cells';
  static const String scripts = '/scripts';

  static String scriptEditor([String? id]) =>
      id == null ? '/scripts/edit' : '/scripts/edit?id=$id';

  static String sessionDetail(String id) => '/sessions/$id';
  static String sessionCells(String id) => '/sessions/$id/cells';
}
