import 'package:flutter/foundation.dart';

/// Compile-time environment config, supplied via
/// `--dart-define-from-file=env/<env>.json`.
class EnvConfig {
  const EnvConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  /// Reads values baked in at compile time. Missing keys become ''.
  const EnvConfig.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment(supabaseUrlKey),
      supabaseAnonKey = const String.fromEnvironment(supabaseAnonKeyKey);

  static const supabaseUrlKey = 'SUPABASE_URL';
  static const supabaseAnonKeyKey = 'SUPABASE_ANON_KEY';

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Names of keys whose value is empty or whitespace-only, in declaration
  /// order.
  List<String> get missingKeys => [
    if (supabaseUrl.trim().isEmpty) supabaseUrlKey,
    if (supabaseAnonKey.trim().isEmpty) supabaseAnonKeyKey,
  ];

  /// Developer hint when keys are missing, `null` when the config is complete.
  String? get missingKeysWarning => missingKeys.isEmpty
      ? null
      : 'EnvConfig: missing ${missingKeys.join(', ')}. '
            'Run with --dart-define-from-file=env/dev.json '
            '(see env/example.json).';
}

/// Prints [EnvConfig.missingKeysWarning] in debug builds; no-op otherwise.
void debugWarnMissingEnv(EnvConfig config) {
  final warning = config.missingKeysWarning;
  if (kDebugMode && warning != null) debugPrint(warning);
}
