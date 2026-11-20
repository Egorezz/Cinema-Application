import 'package:cinema_app/app/app.dart';
import 'package:cinema_app/core/bloc/app_bloc_observer.dart';
import 'package:cinema_app/core/config/env_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy();
  Bloc.observer = const AppBlocObserver();
  debugWarnMissingEnv(const EnvConfig.fromEnvironment());
  runApp(const CinemaApp());
}
