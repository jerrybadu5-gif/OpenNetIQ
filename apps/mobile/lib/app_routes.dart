/// Route paths used with go_router.
abstract final class AppRoutes {
  static const String home = '/';
  static const String signal = '/signal';
  static const String sessions = '/sessions';
  static const String drive = '/drive';

  static String sessionDetail(String id) => '/sessions/$id';
}
