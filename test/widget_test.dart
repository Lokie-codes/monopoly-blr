import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monopoly_blr/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Lobby screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MonopolyApp()));

    // Verify that we are on the lobby screen.
    // The title in AppBar is 'Monopoly LAN' (from MaterialApp title or AppBar title)
    // Let's check what's actually in LobbyScreen
    expect(find.text('Host Game'), findsOneWidget);
    expect(find.text('Join Game'), findsOneWidget);
  });
}
