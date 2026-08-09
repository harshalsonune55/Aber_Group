import 'package:aber_app/core/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('ok carries its value', () {
      const result = Result<int>.ok(42);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('err carries its failure', () {
      const failure = Failure(code: 'not_found', message: 'gone');
      const result = Result<int>.err(failure);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull?.code, 'not_found');
    });

    test('fold dispatches to the matching branch', () {
      const ok = Result<int>.ok(2);
      const err = Result<int>.err(Failure(code: 'x', message: 'y'));
      expect(ok.fold(ok: (v) => v * 10, err: (_) => -1), 20);
      expect(err.fold(ok: (v) => v * 10, err: (_) => -1), -1);
    });

    test('map transforms ok and passes err through untouched', () {
      expect(const Result<int>.ok(3).map((v) => v + 1).valueOrNull, 4);

      const failure = Failure(code: 'boom', message: 'bang');
      final mapped = const Result<int>.err(failure).map((v) => v + 1);
      expect(mapped.failureOrNull?.code, 'boom');
    });
  });

  group('Failure classification', () {
    test('network and timeout are retryable by the sync engine', () {
      expect(
        const Failure(code: 'network_error', message: '').isNetwork,
        isTrue,
      );
      expect(const Failure(code: 'timeout', message: '').isNetwork, isTrue);
      expect(const Failure(code: 'conflict', message: '').isNetwork, isFalse);
    });

    test('conflict is recognised so it can reach the conflicts inbox', () {
      expect(const Failure(code: 'conflict', message: '').isConflict, isTrue);
    });

    test('unauthenticated is detected by code or by status', () {
      expect(
        const Failure(code: 'unauthenticated', message: '').isUnauthenticated,
        isTrue,
      );
      expect(
        const Failure(
          code: 'whatever',
          message: '',
          statusCode: 401,
        ).isUnauthenticated,
        isTrue,
      );
    });

    test('fromApi reads the server problem-details shape', () {
      final failure = Failure.fromApi({
        'code': 'permission_denied',
        'message': 'Not allowed',
        'detail': {'required': 'commission.payout.approve'},
      }, 403);
      expect(failure.code, 'permission_denied');
      expect(failure.statusCode, 403);
      expect(failure.detail['required'], 'commission.payout.approve');
    });

    test('fromApi degrades gracefully on an unexpected body', () {
      final failure = Failure.fromApi(const {}, 500);
      expect(failure.code, 'unknown_error');
      expect(failure.message, isNotEmpty);
    });
  });
}
