import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const InfoPoliticosApp());
}

class InfoPoliticosApp extends StatefulWidget {
  const InfoPoliticosApp({super.key});

  @override
  State<InfoPoliticosApp> createState() => _InfoPoliticosAppState();
}

class _InfoPoliticosAppState extends State<InfoPoliticosApp> {
  late DateTime _now;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final current = DateTime.now();
      if (_shouldRebuildForTheme(current)) {
        setState(() => _now = current);
      } else {
        _now = current;
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  bool _shouldRebuildForTheme(DateTime next) {
    return _isNight(_now) != _isNight(next);
  }

  bool _isNight(DateTime value) {
    return value.hour >= 18 || value.hour < 6;
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = _isNight(_now);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InfoPoliticos',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AppShell(),
    );
  }
}
