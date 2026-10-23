import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/env_config.dart';
import '../error/app_failure.dart';

/// Secure token storage keys used by [DioClient] and Auth repositories.
class AuthStorageKeys {
  const AuthStorageKeys._();

  static const String accessToken = 'anni_access_token';
  static const String refreshToken = 'anni_refresh_token';
  static const String userJson = 'anni_user_profile_json';
}

/// Production HTTP client built on [Dio] with:
/// 1. Automatic JWT Bearer token attachment from [FlutterSecureStorage]
/// 2. Automatic 401 token refresh rotation via `/auth/refresh`
/// 3. Exponential backoff retry interceptor for transient network/5xx errors
/// 4. Structured conversion of [DioException] into [AppFailure]
class DioClient {
  DioClient({
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: EnvConfig.apiBaseUrl,
                connectTimeout: EnvConfig.connectTimeout,
                receiveTimeout: EnvConfig.receiveTimeout,
                headers: const <String, dynamic>{
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _configureInterceptors();
  }

  final FlutterSecureStorage _secureStorage;
  final Dio _dio;
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  Dio get rawDio => _dio;
  FlutterSecureStorage get secureStorage => _secureStorage;

  void _configureInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          try {
            final String? token = await _secureStorage.read(key: AuthStorageKeys.accessToken);
            if (token != null && token.isNotEmpty && !options.headers.containsKey('Authorization')) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (e) {
            AppLogger.warn('Failed reading access token from secure storage', error: e);
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final RequestOptions requestOptions = error.requestOptions;

          // Automatic 401 Refresh Token Rotation
          final bool isAuthEndpoint = requestOptions.path.contains('/auth/login') ||
              requestOptions.path.contains('/auth/register') ||
              requestOptions.path.contains('/auth/refresh');

          if (error.response?.statusCode == 401 &&
              !isAuthEndpoint &&
              requestOptions.extra['retried_after_refresh'] != true) {
            final String? newAccessToken = await _attemptTokenRefresh();
            if (newAccessToken != null && newAccessToken.isNotEmpty) {
              requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              requestOptions.extra['retried_after_refresh'] = true;
              try {
                final Response<dynamic> clonedResponse = await _dio.fetch<dynamic>(requestOptions);
                return handler.resolve(clonedResponse);
              } on DioException catch (retryErr) {
                return handler.next(retryErr);
              }
            }
          }

          // Exponential Backoff Retry for transient network/5xx errors on idempotent requests
          final int retryCount = (requestOptions.extra['retry_count'] as int?) ?? 0;
          if (_shouldRetry(error) && retryCount < 2) {
            final int nextRetry = retryCount + 1;
            requestOptions.extra['retry_count'] = nextRetry;
            final int delayMs = (350 * math.pow(2, retryCount)).toInt();
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            try {
              final Response<dynamic> retryResponse = await _dio.fetch<dynamic>(requestOptions);
              return handler.resolve(retryResponse);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }

          handler.next(error);
        },
      ),
    );
  }

  bool _shouldRetry(DioException error) {
    final String method = error.requestOptions.method.toUpperCase();
    final bool isIdempotent = method == 'GET' || method == 'HEAD' || method == 'OPTIONS';
    if (!isIdempotent) return false;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    final int? statusCode = error.response?.statusCode;
    return statusCode != null && statusCode >= 500 && statusCode < 600;
  }

  Future<String?> _attemptTokenRefresh() async {
    if (_isRefreshing) {
      return _refreshCompleter?.future;
    }
    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final String? refreshToken = await _secureStorage.read(key: AuthStorageKeys.refreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter?.complete(null);
        return null;
      }

      final Dio refreshDio = Dio(
        BaseOptions(
          baseUrl: EnvConfig.apiBaseUrl,
          connectTimeout: EnvConfig.connectTimeout,
          receiveTimeout: EnvConfig.receiveTimeout,
        ),
      );

      final Response<Map<String, dynamic>> response = await refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
      );

      final Map<String, dynamic>? body = response.data;
      final Map<String, dynamic>? dataObj =
          (body?['data'] is Map<String, dynamic>) ? body!['data'] as Map<String, dynamic> : body;

      final String? newAccess = dataObj?['accessToken'] as String?;
      final String? newRefresh = dataObj?['refreshToken'] as String?;

      if (newAccess != null && newAccess.isNotEmpty) {
        await _secureStorage.write(key: AuthStorageKeys.accessToken, value: newAccess);
        if (newRefresh != null && newRefresh.isNotEmpty) {
          await _secureStorage.write(key: AuthStorageKeys.refreshToken, value: newRefresh);
        }
        _refreshCompleter?.complete(newAccess);
        return newAccess;
      } else {
        await clearSession();
        _refreshCompleter?.complete(null);
        return null;
      }
    } catch (e) {
      AppLogger.warn('Token refresh failed, clearing tokens', error: e);
      await clearSession();
      _refreshCompleter?.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: AuthStorageKeys.accessToken, value: accessToken);
    await _secureStorage.write(key: AuthStorageKeys.refreshToken, value: refreshToken);
  }

  Future<void> clearSession() async {
    await _secureStorage.delete(key: AuthStorageKeys.accessToken);
    await _secureStorage.delete(key: AuthStorageKeys.refreshToken);
    await _secureStorage.delete(key: AuthStorageKeys.userJson);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e, st) {
      throw mapDioException(e, st);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e, st) {
      throw mapDioException(e, st);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e, st) {
      throw mapDioException(e, st);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e, st) {
      throw mapDioException(e, st);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e, st) {
      throw mapDioException(e, st);
    }
  }

  /// Maps any [DioException] into a strongly-typed [AppFailure].
  static AppFailure mapDioException(DioException error, [StackTrace? stackTrace]) {
    final int? statusCode = error.response?.statusCode;
    final dynamic responseData = error.response?.data;

    String serverMessage = 'Unable to connect to Anni Music servers.';
    String? serverCode;

    if (responseData is Map<String, dynamic>) {
      if (responseData['error'] is Map<String, dynamic>) {
        final Map<String, dynamic> errMap = responseData['error'] as Map<String, dynamic>;
        serverMessage = (errMap['message'] as String?) ?? serverMessage;
        serverCode = errMap['code'] as String?;
      } else if (responseData['message'] is String) {
        serverMessage = responseData['message'] as String;
      }
    }

    if (statusCode == 401 || statusCode == 403) {
      return AuthFailure(
        message: serverMessage == 'Unable to connect to Anni Music servers.'
            ? 'Your session has expired or credentials are invalid.'
            : serverMessage,
        code: serverCode ?? 'UNAUTHORIZED',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (statusCode == 400 || statusCode == 422) {
      return ValidationFailure(
        message: serverMessage,
        code: serverCode ?? 'VALIDATION_ERROR',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return NetworkFailure(
      message: serverMessage,
      code: serverCode ?? 'NETWORK_ERROR',
      statusCode: statusCode,
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
