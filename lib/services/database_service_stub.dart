// Stub file for web builds - provides dummy implementations
// Real implementations are in database_service_native.dart (for native platforms)

Future<dynamic> initializeNativeDatabase() async {
  throw UnimplementedError('Native database not available on web');
}

dynamic createNativeDatabaseService(dynamic db) {
  throw UnimplementedError('Native database service not available on web');
}
