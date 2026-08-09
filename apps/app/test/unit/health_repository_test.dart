import 'package:aber_app/data/remote/api_client.dart';
import 'package:aber_app/data/repositories/health_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves canned responses without a socket, so these run in CI with no backend.
/// The live end-to-end check lives in `test/e2e_live_backend_test.dart`.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

ApiClient _clientReturning(String body, int status) {
  final dio = Dio();
  dio.httpClientAdapter = _StubAdapter(
    (_) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );
  return ApiClient(dio: dio, baseUrl: 'http://test.local');
}

void main() {
  test('reports the backend as reachable and surfaces its identity', () async {
    final repo = HealthRepository(
      _clientReturning(
        '{"status":"ok","service":"aber-api","version":"0.1.0","environment":"test"}',
        200,
      ),
    );

    final health = await repo.check();
    expect(health.reachable, isTrue);
    expect(health.service, 'aber-api');
    expect(health.version, '0.1.0');
    expect(health.environment, 'test');
    expect(health.failure, isNull);
  });

  test(
    'reports unreachable rather than throwing when the server errors',
    () async {
      final repo = HealthRepository(
        _clientReturning('{"code":"internal_error","message":"boom"}', 500),
      );

      final health = await repo.check();
      expect(health.reachable, isFalse);
      expect(health.failure?.code, 'internal_error');
    },
  );

  test('a mutating request always carries an idempotency key', () async {
    // Losing this header means a retry after a dropped connection creates a
    // second record — a duplicate deal, or a double commission payout.
    RequestOptions? captured;
    final dio = Dio();
    dio.httpClientAdapter = _StubAdapter((options) {
      captured = options;
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await ApiClient(
      dio: dio,
      baseUrl: 'http://test.local',
    ).post<dynamic>('/api/v1/leads', body: {'name': 'test'});

    expect(captured?.headers['Idempotency-Key'], isNotNull);
    expect(captured?.headers['X-Request-ID'], isNotNull);
  });

  test('an explicit idempotency key is preserved across retries', () async {
    // The sync engine reuses the queued mutation's id on every retry, which is
    // exactly what makes the retry safe.
    RequestOptions? captured;
    final dio = Dio();
    dio.httpClientAdapter = _StubAdapter((options) {
      captured = options;
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await ApiClient(dio: dio, baseUrl: 'http://test.local').post<dynamic>(
      '/api/v1/leads',
      body: {'name': 'test'},
      idempotencyKey: 'mutation-abc',
    );

    expect(captured?.headers['Idempotency-Key'], 'mutation-abc');
  });

  test('a connection failure maps to a retryable network failure', () async {
    final dio = Dio();
    dio.httpClientAdapter = _StubAdapter(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'offline',
      ),
    );

    final result = await ApiClient(
      dio: dio,
      baseUrl: 'http://test.local',
    ).get<dynamic>('/health');

    expect(result.isErr, isTrue);
    expect(result.failureOrNull!.isNetwork, isTrue);
  });
}
