/// Gemini API Configuration Template
/// Copy this file to gemini_config.dart and add your API key
/// The gemini_config.dart file is gitignored for security

class GeminiConfig {
  /// Your Gemini API key from Google AI Studio
  /// Get yours at: https://makersuite.google.com/app/apikey
  static const String apiKey = 'YOUR_GEMINI_API_KEY_HERE';
  
  /// Model to use - staying in free tier with web access
  /// Options: 'gemini-1.5-flash', 'gemini-1.5-pro'
  static const String model = 'gemini-1.5-flash';
  
  /// Whether to enable Gemini features
  /// Set to false to disable all Gemini integrations
  static const bool enabled = true;
}
