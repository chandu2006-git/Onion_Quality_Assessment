import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/backend_status.dart';
import 'api_provider.dart';

/// Live readiness of the FastAPI inspection service.
///
/// The capture screen watches this value so a missing model or an offline
/// service is reported before a sample is submitted.
final backendStatusProvider = FutureProvider.autoDispose<BackendStatus>((ref) async {
  final status = await ref.watch(apiServiceProvider).health();
  return status;
});
