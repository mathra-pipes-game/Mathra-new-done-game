import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pipes/data/services/hint_config.dart';
import 'package:pipes/data/services/license_service.dart';

/// Keeps the hint balance.
///  * 3 free hints once per phone (start pool).
///  * Every [HintConfig.pointsPerReward] leaderboard points => +3 hints.
///  * New online #1 => +3 hints (see LicenseService.checkTopAward).
///  * Active subscription (written by the web admin panel) => unlimited.
class HintService extends ChangeNotifier {
  static const String _boxName = 'pipes_settings';
  static const String _fallbackIdKey = 'device_fallback_id';
  static const MethodChannel _channel = MethodChannel('mathra/device');

  Box get _box => Hive.box(_boxName);

  String _deviceId = '';
  LicenseService? license;

  /// Short ID shown to the player (e.g. "A1B2C-3D4E5"). They send it to you.
  String get deviceId => _deviceId;

  /// Must be called once at startup (after Hive is open).
  Future<void> init() async {
    String raw = '';
    try {
      raw = (await _channel.invokeMethod<String>('androidId')) ?? '';
    } catch (_) {}
    if (raw.isEmpty) {
      // Fallback: random id kept in local storage (changes if app data is
      // cleared / reinstalled).
      var fb = _box.get(_fallbackIdKey) as String?;
      if (fb == null) {
        final r = Random.secure();
        fb = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
        await _box.put(_fallbackIdKey, fb);
      }
      raw = fb;
    }
    final h = sha256.convert(utf8.encode('MATHRA-DEVICE|$raw')).toString();
    final s = h.substring(0, 10).toUpperCase();
    _deviceId = '${s.substring(0, 5)}-${s.substring(5)}';

    if (_box.get('hint_start_given') != true) {
      await _box.put('hint_start_bal', HintConfig.startHints);
      await _box.put('hint_start_given', true);
    }
  }

  int get _startBal => (_box.get('hint_start_bal', defaultValue: 0) as int);

  /// True while a web-approved subscription is running.
  bool get isPremium => license?.isActive ?? false;
  bool get isLifetime => isPremium;

  /// Hints this player can use right now.
  int balanceFor(String name) {
    final own = name.trim().isEmpty
        ? 0
        : (_box.get(_k('hint_bal', name), defaultValue: 0) as int);
    return _startBal + own;
  }

  int _ownBal(String name) => name.trim().isEmpty
      ? 0
      : (_box.get(_k('hint_bal', name), defaultValue: 0) as int);

  /// Extra hints (e.g. the online #1 bonus).
  Future<void> grantBonus(String name, int count) async {
    if (name.trim().isEmpty || count <= 0) return;
    await _box.put(_k('hint_bal', name), _ownBal(name) + count);
    notifyListeners();
  }

  String _k(String prefix, String name) =>
      '${prefix}_${name.trim().toLowerCase()}';

  int _setsGiven(String name) =>
      (_box.get(_k('hint_sets', name), defaultValue: 0) as int);

  /// Points still needed for the next free hints.
  int pointsToNext(int score) =>
      HintConfig.pointsPerReward - (score % HintConfig.pointsPerReward);

  /// Call after the score changes. Returns how many hints were just granted.
  /// "Sets given" is never reset, so deleting & re-adding a name can't
  /// farm the same reward twice.
  Future<int> awardForScore(String name, int score) async {
    if (name.trim().isEmpty) return 0;
    final earnedSets = score ~/ HintConfig.pointsPerReward;
    final given = _setsGiven(name);
    if (earnedSets <= given) return 0;
    final granted = (earnedSets - given) * HintConfig.hintsPerReward;
    await _box.put(_k('hint_sets', name), earnedSets);
    await _box.put(_k('hint_bal', name), _ownBal(name) + granted);
    notifyListeners();
    return granted;
  }

  /// Uses one hint. Lifetime players never lose any. False = none left.
  Future<bool> consume(String name) async {
    if (isPremium) return true;
    final own = _ownBal(name);
    if (own > 0) {
      await _box.put(_k('hint_bal', name), own - 1);
    } else if (_startBal > 0) {
      await _box.put('hint_start_bal', _startBal - 1);
    } else {
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Gives one hint back (used if a hint could not be shown).
  Future<void> refund(String name) async {
    if (isPremium) return;
    await _box.put('hint_start_bal', _startBal + 1);
    notifyListeners();
  }
}
