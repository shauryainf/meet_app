import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_2/screens/home_screen.dart';
import 'package:flutter_application_2/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppTheme(),
      child: Consumer<AppTheme>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Video Call App',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
