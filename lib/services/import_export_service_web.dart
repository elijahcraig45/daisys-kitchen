// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> exportFile(String content, String fileName) async {
  final bytes = content.codeUnits;
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<String?> importFile() async {
  final uploadInput = html.FileUploadInputElement()..accept = '.json';
  uploadInput.click();
  
  await uploadInput.onChange.first;
  
  final files = uploadInput.files;
  if (files == null || files.isEmpty) {
    return null;
  }
  
  final file = files[0];
  final reader = html.FileReader();
  
  reader.readAsText(file);
  await reader.onLoad.first;
  
  return reader.result as String;
}
