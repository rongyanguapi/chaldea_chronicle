import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'resource/app_colors.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chaldea Chronicle',
      initialRoute: AppRoutes.root,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.white,
          primaryContainer: AppColors.primaryLight,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.emphasis,
          onSecondary: AppColors.primaryDark,
          secondaryContainer: AppColors.emphasisLight,
          onSecondaryContainer: AppColors.emphasisDark,
          surface: AppColors.pageBackground,
          onSurface: AppColors.primaryDark,
        ),
        scaffoldBackgroundColor: AppColors.pageBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
        ),
        useMaterial3: true,
      ),
    );
  }
}
