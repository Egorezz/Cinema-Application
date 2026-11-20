import 'package:cinema_app/core/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TC1: missingKeys is empty when all keys are set', () {
    const config = EnvConfig(
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: 'abc',
    );
    expect(config.missingKeys, isEmpty);
  });

  test('TC2: missingKeys lists empty and whitespace-only keys', () {
    const config = EnvConfig(supabaseUrl: '', supabaseAnonKey: '  ');
    expect(config.missingKeys, ['SUPABASE_URL', 'SUPABASE_ANON_KEY']);
  });

  test('TC3: missingKeys lists only the empty key', () {
    const config = EnvConfig(
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: '',
    );
    expect(config.missingKeys, ['SUPABASE_ANON_KEY']);
  });

  test('TC4: missingKeysWarning names missing keys, null when complete', () {
    const partial = EnvConfig(supabaseUrl: '', supabaseAnonKey: 'abc');
    final warning = partial.missingKeysWarning;
    expect(warning, contains('SUPABASE_URL'));
    expect(warning, contains('env/dev.json'));
    expect(warning, isNot(contains('SUPABASE_ANON_KEY')));

    const complete = EnvConfig(supabaseUrl: 'u', supabaseAnonKey: 'k');
    expect(complete.missingKeysWarning, isNull);
  });
}
