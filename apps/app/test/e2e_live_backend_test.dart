@Tags(['live'])
library;

import 'dart:io';

import 'package:aber_app/data/remote/api_client.dart';
import 'package:aber_app/data/repositories/health_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Talks to a real running API over a real socket.
///
/// This is the M0 walking-skeleton proof: the Dart client, its interceptors and
/// the FastAPI service genuinely interoperate, rather than agreeing with a stub
/// that we wrote to match our own assumptions.
///
/// Excluded from the default run because it needs a server:
///   make dev                       # in one terminal
///   flutter test --tags live       # in another
void main() {
  const baseUrl = String.fromEnvironment(
    'ABER_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  late ApiClient client;

  setUpAll(() async {
    client = ApiClient(baseUrl: baseUrl);
    try {
      final probe = await HttpClient()
          .getUrl(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      await probe.close();
    } catch (_) {
      fail('No backend at $baseUrl — start it with `make dev`');
    }
  });

  test('the client reaches a live backend and reads its identity', () async {
    final health = await HealthRepository(client).check();

    expect(health.reachable, isTrue, reason: 'backend should be reachable');
    expect(health.service, 'aber-api');
    expect(health.version, isNotEmpty);
  });

  test('the server echoes the request id the client generated', () async {
    // This is what lets a bug report from an agent's phone be traced to a
    // specific server log line.
    final response = await client.dio.get<dynamic>('/health');
    expect(response.headers.value('x-request-id'), isNotNull);
  });

  test('readiness reports on Postgres', () async {
    final response = await client.dio.get<dynamic>('/health/ready');
    final body = response.data as Map<String, dynamic>;
    final deps = (body['dependencies'] as List).cast<Map<String, dynamic>>();

    expect(body['status'], 'ready');
    expect(
      deps.any((d) => d['name'] == 'postgres' && d['healthy'] == true),
      isTrue,
    );
  });
}
