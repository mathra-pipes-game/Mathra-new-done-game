import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pipes/data/services/firebase_config.dart';
import 'package:pipes/data/services/firestore_rest.dart';
import 'package:pipes/data/services/hint_config.dart';
import 'package:pipes/data/services/hint_service.dart';
import 'package:pipes/data/services/leaderboard_service.dart';
import 'package:pipes/data/services/online_leaderboard.dart';

/// One purchasable plan. Prices come from the website admin panel
/// (Firestore `config/plans`), so the web and the game always match.
class ShopPlan {
  const ShopPlan({
    required this.id,
    required this.days,
    required this.price,
    required this.en,
    required this.si,
    this.active = true,
  });

  final String id;
  final int days;
  final int price;
  final String en;
  final String si;
  final bool active;

  factory ShopPlan.fromJson(Map<String, dynamic> m) => ShopPlan(
        id: '${m['id']}',
        days: (m['days'] as num).toInt(),
        price: (m['price'] as num).toInt(),
        en: '${m['en'] ?? '${m['days']} days'}',
        si: '${m['si'] ?? '${m['days']} days'}',
        active: m['active'] != false && m['on'] != false,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'days': days, 'price': price, 'en': en, 'si': si, 'active': active};

  static const List<ShopPlan> defaults = [
    ShopPlan(id: 'd1', days: 1, price: 5, en: '1 Day', si: 'දවස් 1'),
    ShopPlan(id: 'd2', days: 2, price: 10, en: '2 Days', si: 'දවස් 2'),
    ShopPlan(id: 'm1', days: 30, price: 100, en: '1 Month', si: 'මාස 1'),
    ShopPlan(id: 'm2', days: 60, price: 200, en: '2 Months', si: 'මාස 2'),
    ShopPlan(id: 'm6', days: 180, price: 500, en: '6 Months', si: 'මාස 6'),
    ShopPlan(id: 'y1', days: 365, price: 1000, en: '1 Year', si: 'අවුරුද්ද 1'),
  ];
}

/// Subscription ("unlimited hints") state.
///
/// SECURITY MODEL: the app NEVER unlocks anything by itself. Premium is
/// active only while the admin app has written a `subs/<deviceId>`
/// document whose `expiresAt` is in the future (server time). The owner
/// writes that document after checking the payment, and can delete it at
/// any time to remove the plan.
class LicenseService extends ChangeNotifier {
  LicenseService(this.hints) {
    hints.license = this;
  }

  static const String _boxName = 'pipes_settings';
  final HintService hints;
  Box get _box => Hive.box(_boxName);

  List<ShopPlan> plans = ShopPlan.defaults;
  String payInfo = '';
  String whatsapp = HintConfig.whatsappNumber;
  bool loading = false;
  Timer? _expiryTimer;

  // ── license ──
  int get expiresMs => (_box.get('lic_exp', defaultValue: 0) as int);
  String get planLabel => (_box.get('lic_plan', defaultValue: '') as String);
  bool get isActive => expiresMs > Fs.nowMs;
  DateTime? get expiresAt =>
      isActive ? DateTime.fromMillisecondsSinceEpoch(expiresMs) : null;

  // ── order ──
  String get orderId => (_box.get('order_id', defaultValue: '') as String);
  String get orderStatus => (_box.get('order_status', defaultValue: '') as String);
  String get orderPlanLabel => (_box.get('order_plan', defaultValue: '') as String);

  Future<void> init() async {
    final cached = _box.get('shop_plans_json') as String?;
    if (cached != null) _parsePlans(cached);
    payInfo = (_box.get('shop_pay_info', defaultValue: '') as String);
    _scheduleExpiry();
  }

  void _parsePlans(String json) {
    try {
      final list = (jsonDecode(json) as List)
          .map((e) => ShopPlan.fromJson((e as Map).cast<String, dynamic>()))
          .where((p) => p.active)
          .toList();
      if (list.isNotEmpty) plans = list;
    } catch (_) {}
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final left = expiresMs - Fs.nowMs;
    if (left > 0) {
      _expiryTimer = Timer(Duration(milliseconds: min(left + 500, 86400000)), () {
        notifyListeners();
        _scheduleExpiry();
      });
    }
  }

  /// Called on every app start: counts this phone as an install / visit.
  Future<void> registerOpen(String playerName) async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      final id = hints.deviceId;
      final now = Fs.nowMs;
      final cur = await Fs.getFields('devices/$id');
      if (cur == null) {
        await Fs.create('devices', id, {
          'firstSeen': Fs.i(now),
          'lastSeen': Fs.i(now),
          'opens': Fs.i(1),
          'version': Fs.s(_appVersion),
        });
      } else {
        await Fs.patch('devices/$id', {
          'lastSeen': Fs.i(now),
          'opens': Fs.i(Fs.intv(cur, 'opens') + 1),
          'version': Fs.s(_appVersion),
        });
      }
    } catch (_) {}
  }

  static const String _appVersion = '1.3.0';

  /// Counts that this phone opened the plans screen (shown in the admin app).
  Future<void> recordPlanView() async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      await Fs.increment('devices/${hints.deviceId}', 'planViews');
    } catch (_) {}
  }

  Future<void> refreshAll() async {
    await Future.wait([loadPlans(), refreshLicense()]);
  }

  Future<void> loadPlans() async {
    if (!FirebaseConfig.isConfigured) return;
    loading = true;
    notifyListeners();
    try {
      final p = await Fs.getFields('config/plans');
      var json = Fs.str(p, 'plans');
      if (json.isEmpty) json = Fs.str(p, 'itemsJson');
      if (json.isNotEmpty) {
        await _box.put('shop_plans_json', json);
        _parsePlans(json);
      }
      final info = Fs.str(p, 'payInfo');
      if (info.isNotEmpty) {
        payInfo = info;
        await _box.put('shop_pay_info', payInfo);
      }
      final w = Fs.str(p, 'whatsapp').replaceAll(RegExp(r'[^0-9]'), '');
      if (w.isNotEmpty) whatsapp = w;
    } catch (_) {}
    loading = false;
    notifyListeners();
  }

  /// Reads this phone's license from the server. 404 = no plan (or the
  /// owner removed it) -> premium is switched off immediately.
  Future<void> refreshLicense() async {
    if (!FirebaseConfig.isConfigured) return;
    try {
      final f = await Fs.getFields('subs/${hints.deviceId}');
      if (f == null || Fs.boolv(f, 'revoked')) {
        await _box.put('lic_exp', 0);
        await _box.put('lic_plan', '');
      } else {
        await _box.put('lic_exp', Fs.intv(f, 'expiresAt'));
        await _box.put('lic_plan', Fs.str(f, 'planName'));
      }
      _scheduleExpiry();
      notifyListeners();
    } catch (_) {
      // Offline: keep the cached license (still checked against expiry).
    }
  }

  /// Places an order. The player then pays and the owner approves it in the
  /// web panel. Returns the order code (or null on failure).
  Future<String?> placeOrder(ShopPlan plan, String playerName, String payRef) async {
    if (!FirebaseConfig.isConfigured) return null;
    final r = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final id = List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
    try {
      await Fs.create('orders', id, {
        'deviceId': Fs.s(hints.deviceId),
        'playerName': Fs.s(playerName),
        'planId': Fs.s(plan.id),
        'planName': Fs.s(plan.en),
        'days': Fs.i(plan.days),
        'price': Fs.i(plan.price),
        'status': Fs.s('pending'),
        'createdAt': Fs.i(Fs.nowMs),
      });
      await _box.put('order_id', id);
      await _box.put('order_status', 'pending');
      await _box.put('order_plan', '${plan.en} • Rs. ${plan.price}');
      notifyListeners();
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Checks the status of the last order (pending / approved / rejected).
  Future<void> refreshOrder() async {
    final id = orderId;
    if (id.isEmpty || !FirebaseConfig.isConfigured) return;
    try {
      final f = await Fs.getFields('orders/$id');
      if (f == null) return;
      final st = Fs.str(f, 'status', 'pending');
      await _box.put('order_status', st == 'paid' ? 'approved' : st);
      await refreshLicense();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearOrder() async {
    await _box.delete('order_id');
    await _box.delete('order_status');
    await _box.delete('order_plan');
    notifyListeners();
  }

  /// +3 hints for the player who has just TAKEN the #1 spot of the online
  /// leaderboard. `meta/top` remembers the current #1, so each new #1 is
  /// rewarded once; the player who was pushed down to #2 gets nothing.
  Future<int> checkTopAward(LeaderboardService board) async {
    if (!FirebaseConfig.isConfigured || !board.hasPlayer) return 0;
    final list = board.onlineBoard?.players ?? const <PlayerEntry>[];
    if (list.isEmpty) return 0;
    final top = list.first;
    final myId = OnlineLeaderboard.docId(board.deviceId, board.playerName);
    if (top.docId != myId || top.score <= 0) return 0;

    final meta = await Fs.getFields('meta/top');
    if (Fs.str(meta, 'holder') == myId) return 0; // already rewarded

    final now = Fs.nowMs;
    await Fs.patch('meta/top', {
      'holder': Fs.s(myId),
      'name': Fs.s(board.playerName),
      'updatedAt': Fs.i(now),
    });
    try {
      await Fs.create('topAwards', '${now}_$myId', {
        'holder': Fs.s(myId),
        'name': Fs.s(board.playerName),
        'score': Fs.i(top.score),
        'at': Fs.i(now),
      });
    } catch (_) {}
    await hints.grantBonus(board.playerName, HintConfig.topReward);
    return HintConfig.topReward;
  }
}
