import 'package:cinema_app/app/router.dart';
import 'package:cinema_app/core/l10n/strings.dart';
import 'package:cinema_app/core/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CinemaApp extends StatefulWidget {
  const CinemaApp({super.key, this._router});

  /// Injectable for tests. An injected router is owned by the caller.
  final GoRouter? _router;

  @override
  State<CinemaApp> createState() => _CinemaAppState();
}

class _CinemaAppState extends State<CinemaApp> {
  late final GoRouter _router;
  late final bool _ownsRouter;

  @override
  void initState() {
    super.initState();
    _ownsRouter = widget._router == null;
    _router = widget._router ?? createRouter();
  }

  @override
  void didUpdateWidget(CinemaApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(oldWidget._router, widget._router),
      'CinemaApp.router must not change after the first build.',
    );
  }

  @override
  void dispose() {
    if (_ownsRouter) {
      _router.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppStrings.appTitle,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
