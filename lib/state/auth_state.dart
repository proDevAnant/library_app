import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/nav.dart';
import '../models/session.dart';

/// Who is logged in. The whole app rebuilds from this.
class AuthState extends ChangeNotifier {
  static const _tokenKey = 'auth_token';

  AppUser? user;
  bool ready = false;
  String? startupError;

  AuthState() {
    Api.instance.onUnauthorized = () => _clear(message: 'Your session has ended. Please log in again.');
  }

  /// Message to show once on the login screen (e.g. "session ended").
  String? loginNotice;

  Future<void> init() async {
    startupError = null;
    ready = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      Api.instance.token = token;
      try {
        final r = await Api.instance.get('/auth/me');
        user = AppUser.fromJson(r.map);
      } on ApiException catch (e) {
        if (e.status == 401 || e.status == 403) {
          await _clear(message: e.message);
        } else {
          // offline or server problem: keep the saved login and offer "Try again"
          startupError = e.message;
          notifyListeners();
          return;
        }
      }
    }
    ready = true;
    notifyListeners();
  }

  /// Throws ApiException. status 409 + errors['library_code'] means "ask for library code".
  Future<void> login(String phone, String password, {String? libraryCode}) async {
    final r = await Api.instance.post('/auth/login', {
      'phone': phone,
      'password': password,
      if (libraryCode != null && libraryCode.isNotEmpty) 'library_code': libraryCode,
      'device_name': 'Android app',
    });
    final token = r.map['token'].toString();
    Api.instance.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    user = AppUser.fromJson((r.map['user'] as Map).cast<String, dynamic>());
    loginNotice = null;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    final r = await Api.instance.get('/auth/me');
    user = AppUser.fromJson(r.map);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await Api.instance.post('/auth/logout');
    } catch (_) {
      // even if offline, forget the login on this phone
    }
    await _clear();
  }

  Future<void> _clear({String? message}) async {
    Api.instance.token = null;
    user = null;
    ready = true;
    loginNotice = message;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    notifyListeners();
  }
}
