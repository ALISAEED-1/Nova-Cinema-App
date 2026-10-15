import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/app_user.dart';
import '../../models/checkout_session.dart';
import '../../models/subscription_plan.dart';
import 'nova_api.dart';

/// [NovaApi] over HTTP + JSON.
class HttpNovaApi implements NovaApi {
  HttpNovaApi({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl.replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  static const _timeout = Duration(seconds: 15);

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String country,
  }) async {
    final json = await _send('POST', '/v1/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      'country': country,
    });
    return _authResult(json);
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final json = await _send('POST', '/v1/auth/login', body: {
      'email': email,
      'password': password,
    });
    return _authResult(json);
  }

  @override
  Future<AppUser> fetchAccount(String token) async =>
      AppUser.fromAccountJson(await _send('GET', '/v1/me', token: token));

  @override
  Future<AppUser> updateAccount(
    String token, {
    String? name,
    String? country,
  }) async =>
      AppUser.fromAccountJson(
        await _send('PATCH', '/v1/me', token: token, body: {
          if (name != null) 'name': name,
          if (country != null) 'country': country,
        }),
      );

  @override
  Future<List<BillingCountry>> fetchCountries() async {
    final json = await _send('GET', '/v1/regions');
    return (json['countries'] as List)
        .map((c) => BillingCountry.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PlanCatalog> fetchPlans(String token) async =>
      PlanCatalog.fromJson(await _send('GET', '/v1/plans', token: token));

  @override
  Future<CheckoutSession> createCheckoutSession(
    String token, {
    required String planId,
    required String idempotencyKey,
  }) async =>
      CheckoutSession.fromJson(
        await _send(
          'POST',
          '/v1/checkout/sessions',
          token: token,
          body: {'planId': planId},
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      );

  @override
  Future<CheckoutSession> fetchCheckoutSession(
    String token,
    String sessionId,
  ) async =>
      CheckoutSession.fromJson(
        await _send(
          'GET',
          '/v1/checkout/sessions/${Uri.encodeComponent(sessionId)}',
          token: token,
        ),
      );

  AuthResult _authResult(Map<String, dynamic> json) => AuthResult(
        token: json['token'] as String,
        user: AppUser.fromAccountJson(json['account'] as Map<String, dynamic>),
      );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        ...headers,
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw const ApiException('The server took too long to answer. Try again.');
    } on http.ClientException {
      throw const ApiException(
        'Can’t reach the Nova Cinema server. Check your connection and try again.',
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      json = const {};
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;

    final error = json['error'] as Map<String, dynamic>?;
    throw ApiException(
      error?['message'] as String? ?? 'Something went wrong. Please try again.',
      statusCode: response.statusCode,
      code: error?['code'] as String?,
    );
  }
}
