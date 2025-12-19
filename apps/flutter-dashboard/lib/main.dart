import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/metrics_service.dart';
import 'providers/metrics_provider.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const EdgeAnalyticsApp());
}

class EdgeAnalyticsApp extends StatelessWidget {
  const EdgeAnalyticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MetricsProvider(MetricsService()),
        ),
      ],
      child: MaterialApp(
        title: 'Edge Analytics Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF1A1A2E),
          cardTheme: CardTheme(
            color: const Color(0xFF16213E),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
