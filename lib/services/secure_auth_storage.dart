import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureAuthStorage {
  static const _pinKey = 'user_pin_hash';
  static const _hasOnboardedKey = 'has_onboarded';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> savePin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
  }

  static Future<bool> hasPin() async {
    final v = await _storage.read(key: _pinKey);
    return v != null && v.isNotEmpty;
  }

  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  static Future<void> setOnboarded() async {
    await _storage.write(key: _hasOnboardedKey, value: 'true');
  }

  static Future<bool> hasOnboarded() async {
    final v = await _storage.read(key: _hasOnboardedKey);
    return v == 'true';
  }

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
