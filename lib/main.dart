import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/feed_store.dart';
import 'state/session.dart';
import 'theme.dart';

void main() {
  runApp(const PhotoShareApp());
}

class PhotoShareApp extends StatelessWidget {
  const PhotoShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Session()..init(),
      child: MaterialApp(
        title: 'PhotoShare',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    switch (session.state) {
      case AuthState.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthState.signedOut:
        return const SignInScreen();
      case AuthState.signedIn:
        return ChangeNotifierProvider(create: (_) => FeedStore(session.api)..load(), child: const HomeScreen());
    }
  }
}
