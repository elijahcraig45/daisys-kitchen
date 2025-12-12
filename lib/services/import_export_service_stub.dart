// Stub for platforms we don't support
Future<void> exportFile(String content, String fileName) async {
  throw UnimplementedError('Export not supported on this platform');
}

Future<String?> importFile() async {
  throw UnimplementedError('Import not supported on this platform');
}
