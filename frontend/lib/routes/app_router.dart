import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/start_inspection_screen.dart';
import '../screens/capture_screen.dart';
import '../screens/results_screen.dart';
import '../screens/about_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/start', builder: (context, state) => const StartInspectionScreen()),
    GoRoute(path: '/capture', builder: (context, state) => const CaptureScreen()),
    GoRoute(path: '/results', builder: (context, state) => const ResultsScreen()),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
  ],
);