import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/discover_screen.dart';
import 'dart:io';
import 'screens/connect_screen.dart';
import 'screens/control_screen.dart';
import 'screens/main_tab_screen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(const RemoteControlApp());
}

class RemoteControlApp extends StatelessWidget {
  const RemoteControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remote Control',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Tailwind slate-900
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8), // Light blue neon
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
          primary: const Color(0xFF38BDF8),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const DiscoverScreen(),
        '/connect': (context) => const ConnectScreen(),
        '/control': (context) => const MainTabScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
