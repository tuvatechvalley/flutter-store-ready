import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/errors/app_failure.dart';
import 'package:starter_app/core/errors/failure_mapper.dart';

DioException _response(
  int status, {
  Object? data,
  Map<String, List<String>>? headers,
}) {
  final request = RequestOptions(path: '/x');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response<Object?>(
      requestOptions: request,
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers ?? {}),
    ),
  );
}

void main() {
  test('maps HTTP status codes', () {
    expect(mapToFailure(_response(401)), isA<UnauthorizedFailure>());
    expect(mapToFailure(_response(403)), isA<ForbiddenFailure>());
    expect(mapToFailure(_response(404)), isA<NotFoundFailure>());
    expect(mapToFailure(_response(503)), isA<ServerFailure>());
  });

  test('parses validation errors defensively', () {
    final failure = mapToFailure(
      _response(
        422,
        data: {
          'message': 'Invalid',
          'errors': {'email': 'taken', 'x': 42},
        },
      ),
    );
    expect(failure, isA<ValidationFailure>());
    failure as ValidationFailure;
    expect(failure.fieldErrors, {'email': 'taken'});
    expect(failure.serverMessage, 'Invalid');
    // Non-map bodies (HTML error pages) never crash the mapper.
    expect(
      mapToFailure(_response(400, data: '<html>')),
      isA<ValidationFailure>(),
    );
  });

  test('429 reads Retry-After and caps it', () {
    final f = mapToFailure(
      _response(
        429,
        headers: {
          'retry-after': ['99999'],
        },
      ),
    );
    expect((f as RateLimitedFailure).retryAfter, const Duration(minutes: 10));
  });

  test('maps transport errors', () {
    final request = RequestOptions(path: '/x');
    expect(
      mapToFailure(
        DioException.connectionTimeout(
          timeout: Duration.zero,
          requestOptions: request,
        ),
      ),
      isA<TimeoutFailure>(),
    );
    expect(
      mapToFailure(DioException.badCertificate(requestOptions: request)),
      isA<SecurityFailure>(),
    );
    expect(
      mapToFailure(
        DioException.connectionError(
          requestOptions: request,
          reason: 'x',
          error: const SocketException('x'),
        ),
      ),
      isA<NetworkFailure>(),
    );
    expect(
      mapToFailure(const FormatException('bad json')),
      isA<DataFormatFailure>(),
    );
    expect(mapToFailure(StateError('boom')), isA<UnexpectedFailure>());
  });

  test('guardFailures converts thrown errors to AppFailure', () async {
    await expectLater(
      guardFailures<void>(() async => throw const SocketException('offline')),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('expected failures are not reported, bugs are', () {
    expect(const NetworkFailure().shouldReport, isFalse);
    expect(const NotFoundFailure().shouldReport, isFalse);
    expect(const UnexpectedFailure().shouldReport, isTrue);
    expect(const SecurityFailure().shouldReport, isTrue);
  });
}
