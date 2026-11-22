import 'package:flutter/material.dart';

import 'screens/projects_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TattooStudioApp());
}

class TattooStudioApp extends StatelessWidget {
  const TattooStudioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tattoo Studio',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF323B43),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F7F5),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F7F5),
          ),
        ),
        home: const ProjectsScreen(),
      );
}
