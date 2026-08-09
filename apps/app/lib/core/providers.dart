import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/api_client.dart';
import '../data/repositories/health_repository.dart';

/// Compile-safe dependency injection. Tests override these with fakes via
/// `ProviderScope(overrides: [...])` rather than reaching for a service locator.

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dio.close);
  return client;
});

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepository(ref.watch(apiClientProvider)),
);

/// Backend reachability, used by the M0 walking-skeleton screen and later by the
/// sync engine's connectivity banner.
final apiHealthProvider = FutureProvider.autoDispose<ApiHealth>(
  (ref) async => ref.watch(healthRepositoryProvider).check(),
);
