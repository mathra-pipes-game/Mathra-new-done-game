import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pipes/data/services/hint_config.dart';
import 'package:pipes/data/services/license_service.dart';
import 'package:pipes/ui/core/l10n.dart';
import 'package:pipes/ui/core/theme/app_colors.dart';
import 'package:pipes/ui/core/widgets/premium.dart';
import 'package:pipes/ui/core/widgets/tangible_button.dart';
import 'package:pipes/ui/providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shop: unlimited-hint plans. Prices are loaded from the website admin
/// panel, so the app and the website always show the same prices.
class ShopView extends ConsumerStatefulWidget {
  const ShopView({super.key});

  @override
  ConsumerState<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends ConsumerState<ShopView> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final lic = ref.read(licenseProvider);
    Future.microtask(() async {
      lic.recordPlanView();
      await lic.refreshAll();
      await lic.refreshOrder();
    });
    // While an order is waiting, ask the server every 10 seconds.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (lic.orderStatus == 'pending') lic.refreshOrder();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _whatsapp(LicenseService lic, String text) async {
    try {
      await launchUrl(
        Uri.parse('https://wa.me/${lic.whatsapp}?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _buy(ShopPlan plan) async {
    final lic = ref.read(licenseProvider);
    final board = ref.read(leaderboardProvider);
    final ref0 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '${plan.en} – Rs. ${plan.price}',
          style: TextStyle(color: AppColors.headingDark, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              L10n.d(
                'An order is created. Pay Rs. ${plan.price}, then the owner confirms it on the website and your plan starts automatically.',
                'Order එකක් හැදෙනවා. රු. ${plan.price} ක් ගෙවන්න, ඊට පස්සේ අයිතිකරු වෙබ් එකෙන් තහවුරු කළාම plan එක ඉබේම පටන් ගන්නවා.',
              ),
              style: TextStyle(fontSize: 13, color: AppColors.subtext),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ref0,
              style: TextStyle(color: AppColors.headingDark),
              decoration: InputDecoration(
                hintText: L10n.t('Payment reference (optional)', 'ගෙවීම් reference (අවශ්‍ය නම්)'),
                hintStyle: TextStyle(color: AppColors.subtext),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.t('Cancel', 'අවලංගු'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L10n.t('Order', 'Order කරන්න'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final id = await lic.placeOrder(plan, board.playerName, ref0.text.trim());
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.t('Could not create the order. Check internet.', 'Order එක හැදුවේ නෑ. ඉන්ටර්නෙට් බලන්න.')),
      ));
      return;
    }
    _whatsapp(lic, 'Hi! Mathra Pipes order $id\nPlan: ${plan.en} (Rs. ${plan.price})\nDevice ID: ${ref.read(hintServiceProvider).deviceId}');
  }

  @override
  Widget build(BuildContext context) {
    final lic = ref.watch(licenseProvider);
    final hints = ref.watch(hintServiceProvider);
    final board = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: PremiumBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([lic, hints]),
            builder: (context, _) {
              final exp = lic.expiresAt;
              return Column(
                children: [
                  PremiumHeader(title: L10n.t('Shop 👑', 'වෙළඳසැල 👑')),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      children: [
                        _card(
                          title: exp != null
                              ? '👑 ${L10n.t('Premium active', 'Premium ක්‍රියාත්මකයි')}'
                              : '⭐ ${L10n.t('Free plan', 'නොමිලේ plan')}',
                          body: exp != null
                              ? L10n.d('Unlimited hints until ${_date(exp)}', 'අසීමිත ඉඟි ${_date(exp)} දක්වා')
                              : L10n.d(
                                  'Hints left: ${hints.balanceFor(board.playerName)}.\nEvery ${HintConfig.pointsPerReward} points = ${HintConfig.hintsPerReward} hints. New #1 on the leaderboard = +${HintConfig.topReward}.',
                                  'ඉතිරි ඉඟි: ${hints.balanceFor(board.playerName)}.\nලකුණු ${HintConfig.pointsPerReward} ක් = ඉඟි ${HintConfig.hintsPerReward}. Leaderboard #1 වුණාම +${HintConfig.topReward}.',
                                ),
                        ),
                        if (lic.orderId.isNotEmpty && lic.orderStatus != 'approved') ...[
                          const SizedBox(height: 12),
                          _orderCard(lic),
                        ],
                        if (lic.payInfo.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _card(title: '💳 ${L10n.t('How to pay', 'ගෙවන්නේ කොහොමද')}', body: lic.payInfo),
                        ],
                        const SizedBox(height: 14),
                        TangibleButton(
                          text: 'WhatsApp  +${lic.whatsapp}',
                          icon: Icons.chat_rounded,
                          height: 64,
                          backgroundColor: const Color(0xFF25D366),
                          textColor: Colors.white,
                          onPressed: () => _whatsapp(
                            lic,
                            'Hi! Mathra Pipes – Device ID: ${hints.deviceId}',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          L10n.t('Unlimited hints plans', 'අසීමිත ඉඟි plans'),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.headingDark),
                        ),
                        const SizedBox(height: 8),
                        for (final p in lic.plans) _planTile(p, lic),
                        const SizedBox(height: 10),
                        Text(
                          L10n.d(
                            'Plans end automatically. Activation only happens through the website after the payment is checked.',
                            'Plan එක ඉබේම අවසන් වෙනවා. ගෙවීම පරීක්ෂා කළාට පස්සේ වෙබ් එක හරහා විතරයි activate වෙන්නේ.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: AppColors.subtext),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: hints.deviceId));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(L10n.t('Device ID copied', 'Device ID copy වුණා'))),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Device ID: ${hints.deviceId}',
                                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.headingDark)),
                                const SizedBox(width: 8),
                                Icon(Icons.copy_rounded, size: 16, color: AppColors.subtext),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(HintConfig.webUrl, style: TextStyle(fontSize: 11.5, color: AppColors.subtext)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _orderCard(LicenseService lic) {
    final rejected = lic.orderStatus == 'rejected';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (rejected ? Colors.red : Colors.orange).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rejected ? Colors.red : Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rejected
                ? '❌ ${L10n.t('Order rejected', 'Order එක ප්‍රතික්ෂේප විය')}'
                : '⏳ ${L10n.t('Waiting for confirmation', 'තහවුරු කිරීම බලාපොරොත්තුවෙන්')}',
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.headingDark),
          ),
          const SizedBox(height: 4),
          Text('Order: ${lic.orderId}  •  ${lic.orderPlanLabel}',
              style: TextStyle(color: AppColors.subtext, fontSize: 12.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TangibleButton(
                  text: L10n.t('WhatsApp', 'WhatsApp'),
                  icon: Icons.chat_rounded,
                  isSecondary: true,
                  height: 56,
                  onPressed: () => _whatsapp(
                    lic,
                    'Hi! Mathra Pipes order ${lic.orderId}\nDevice ID: ${ref.read(hintServiceProvider).deviceId}',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TangibleButton(
                  text: rejected ? L10n.t('Clear', 'ඉවත් කරන්න') : L10n.t('Check now', 'දැන් බලන්න'),
                  icon: rejected ? Icons.close_rounded : Icons.refresh_rounded,
                  height: 56,
                  onPressed: () => rejected ? lic.clearOrder() : lic.refreshOrder(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planTile(ShopPlan p, LicenseService lic) {
    final busy = lic.orderId.isNotEmpty && lic.orderStatus == 'pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.t(p.en, p.si),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.headingDark)),
                  Text('Rs. ${p.price}',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accent)),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: TangibleButton(
                text: L10n.t('Buy', 'මිලදී ගන්න'),
                icon: Icons.shopping_cart_rounded,
                height: 40,
                backgroundColor: AppColors.accent,
                textColor: Colors.white,
                onPressed: busy ? null : () => _buy(p),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.headingDark)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 13, color: AppColors.subtext)),
        ],
      ),
    );
  }
}
