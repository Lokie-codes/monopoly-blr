import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/game/ui/lobby_screen.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MonopolyApp()));
}

class MonopolyApp extends StatelessWidget {
  const MonopolyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monopoly LAN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LobbyScreen(),
    );
  }
}
