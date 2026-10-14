import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';

/// Thrown for every failed request. [errors] holds per-field messages (422).
class ApiException implements Exception {
  final String message;
  final int status;
  final Map<String, String> errors;

  ApiException(this.message, {this.status = 0, this.errors = const {}});

  @override
  String toString() => message;
}

/// A successful reply: { success, message, data, meta }.
class ApiResponse {
  final dynamic data;
  final Map<String, dynamic> meta;
  final String message;

  ApiResponse(this.data, this.meta, this.message);

  Map<String, dynamic> get map => (data as Map).cast<String, dynamic>();

  List<Map<String, dynamic>> get list =>
      (data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
}

/// Talks to the PHP backend. One shared instance: Api.instance
class Api {
  Api._();
  static final Api instance = Api._();

  String? token;

  /// Called when the server says the session has ended (401).
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<ApiResponse> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body: body ?? const {});

  Future<ApiResponse> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body: body);

  Future<ApiResponse> delete(String path, [Map<String, dynamic>? body]) =>
      _send('DELETE', path, body: body ?? const {});

  Uri _uri(String path, Map<String, dynamic>? query) {
    final base = Uri.parse('${AppConfig.apiBase}$path');
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) q[k] = v.toString();
    });
    return q.isEmpty ? base : base.replace(queryParameters: q);
  }

  Future<ApiResponse> _send(String method, String path,
      {Map<String, dynamic>? query, Object? body}) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    late http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers).timeout(AppConfig.timeout);
          break;
        case 'POST':
          res = await http.post(uri, headers: _headers, body: encoded).timeout(AppConfig.timeout);
          break;
        case 'PUT':
          res = await http.put(uri, headers: _headers, body: encoded).timeout(AppConfig.timeout);
          break;
        default:
          res = await http.delete(uri, headers: _headers, body: encoded).timeout(AppConfig.timeout);
      }
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('The server is taking too long. Please try again.');
    } on http.ClientException {
      throw ApiException('Could not reach the server. Please try again.');
    }
    return _handle(res);
  }

  ApiResponse _handle(http.Response res) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) throw const FormatException();
      json = decoded.cast<String, dynamic>();
    } catch (_) {
      throw ApiException('Unexpected reply from the server (${res.statusCode}).', status: res.statusCode);
    }

    if (json['success'] == true) {
      final meta = json['meta'];
      return ApiResponse(
        json['data'],
        meta is Map ? meta.cast<String, dynamic>() : <String, dynamic>{},
        (json['message'] ?? '').toString(),
      );
    }

    final errs = <String, String>{};
    final rawErrors = json['errors'];
    if (rawErrors is Map) {
      rawErrors.forEach((k, v) => errs[k.toString()] = v.toString());
    }
    if (res.statusCode == 401 && token != null) {
      onUnauthorized?.call();
    }
    throw ApiException(
      (json['message'] ?? 'Something went wrong').toString(),
      status: res.statusCode,
      errors: errs,
    );
  }
}
