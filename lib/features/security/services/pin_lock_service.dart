import 'package:shared_preferences/shared_preferences.dart';

/// Local PIN lock service.
///
/// Stores a 4-digit PIN in SharedPreferences as requested.
/// Note: For stronger security in production, consider encrypted storage.
class PinLockService {
  PinLockService._internal();

  static final PinLockService instance = PinLockService._internal();

  static const String _pinKey = 'anonnote_pin_code';

  bool _isValidPin(String pin) => RegExp(r'^\d{4}$').hasMatch(pin);

  Future<String?> _readPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    if (pin == null || !_isValidPin(pin)) return null;
    return pin;
  }

  Future<bool> hasPin() async => (await _readPin()) != null;

  Future<void> setPin(String pin) async {
    if (!_isValidPin(pin)) {
      throw ArgumentError('PIN must be exactly 4 digits');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  Future<bool> verifyPin(String pin) async {
    if (!_isValidPin(pin)) return false;
    final stored = await _readPin();
    if (stored == null) return false;
    return stored == pin;
  }

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final ok = await verifyPin(currentPin);
    if (!ok) return false;
    await setPin(newPin);
    return true;
  }

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
  }
}
