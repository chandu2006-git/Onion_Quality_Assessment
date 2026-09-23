import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';

/// Single HTTP client shared by the application.
final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  ref.onDispose(service.dispose);
  return service;
});
