import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: C.card,
    ),
  );
  var seen = false;
  try {
    final p = await SharedPreferences.getInstance();
    seen = p.getBool('intro_seen') ?? false;
  } catch (_) {}
  runApp(ZayaanApp(showIntro: !seen));
}

class ZayaanApp extends StatelessWidget {
  final bool showIntro;
  const ZayaanApp({super.key, required this.showIntro});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZEVN Player',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: showIntro ? const _IntroGate() : const Shell(),
    );
  }
}

class _IntroGate extends StatelessWidget {
  const _IntroGate();

  Future<void> _start(BuildContext context) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('intro_seen', true);
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Shell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SplashPage(onStart: () => _start(context));
  }
}
