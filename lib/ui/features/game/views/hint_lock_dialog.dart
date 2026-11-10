import 'package:flutter/material.dart';
import 'package:pipes/data/services/hint_config.dart';
import 'package:pipes/data/services/hint_service.dart';
import 'package:pipes/data/services/leaderboard_service.dart';
import 'package:pipes/data/services/license_service.dart';
import 'package:pipes/ui/core/l10n.dart';
import 'package:pipes/ui/core/theme/app_colors.dart';
import 'package:pipes/ui/core/widgets/tangible_button.dart';
import 'package:pipes/ui/features/shop/views/shop_view.dart';

/// Shown when the player has 0 hints. Explains how to earn more and opens
/// the Shop (plans are activated only through the website).
Future<void> showHintLockDialog(
  BuildContext context,
  HintService hints,
  LeaderboardService board,
  LicenseService license,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _HintLockDialog(hints: hints, board: board, license: license),
  );
}

class _HintLockDialog extends StatelessWidget {
  const _HintLockDialog({required this.hints, required this.board, required this.license});
  final HintService hints;
  final LeaderboardService board;
  final LicenseService license;

  @override
  Widget build(BuildContext context) {
    final score = board.me?.score ?? 0;
    final need = hints.pointsToNext(score);
    final cheapest = license.plans.isEmpty
        ? null
        : (license.plans.toList()..sort((a, b) => a.price.compareTo(b.price))).first;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '🔒  ${L10n.t('Hints finished', 'ඉඟි ඉවරයි')}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.headingDark),
              ),
              const SizedBox(height: 12),
              _box(
                title: '⭐ ${L10n.t('Free hints', 'නොමිලේ ඉඟි')}',
                body: board.hasPlayer
                    ? L10n.d(
                        'Every ${HintConfig.pointsPerReward} leaderboard points = ${HintConfig.hintsPerReward} hints.\nYour score: $score  •  $need more points for the next ${HintConfig.hintsPerReward}.\nTake the #1 spot online = +${HintConfig.topReward} hints.',
                        'Leaderboard ලකුණු ${HintConfig.pointsPerReward} ක් = ඉඟි ${HintConfig.hintsPerReward}.\nඔයාගේ ලකුණු: $score  •  ඊළඟ ඉඟි ${HintConfig.hintsPerReward} ට තව ලකුණු $need ක්.\nOnline #1 වුණාම ඉඟි +${HintConfig.topReward}.',
                      )
                    : L10n.d(
                        'Solve a level and enter your name. Every ${HintConfig.pointsPerReward} leaderboard points = ${HintConfig.hintsPerReward} hints.',
                        'Level එකක් ඉවර කරලා නම දාන්න. ලකුණු ${HintConfig.pointsPerReward} ක් = ඉඟි ${HintConfig.hintsPerReward}.',
                      ),
              ),
              const SizedBox(height: 10),
              _box(
                title: '👑 ${L10n.t('Unlimited hints', 'අසීමිත ඉඟි')}${cheapest == null ? '' : ' – ${L10n.t('from', 'සිට')} Rs. ${cheapest.price}'}',
                body: L10n.d(
                  'Pick a plan (1 day up to 1 year). It starts after the owner confirms your payment on the website and ends automatically.',
                  'Plan එකක් තෝරන්න (දවස් 1 සිට අවුරුද්ද දක්වා). ගෙවීම වෙබ් එකෙන් තහවුරු කළාම පටන් අරන් ඉබේම අවසන් වෙනවා.',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TangibleButton(
                      text: L10n.t('Close', 'වසන්න'),
                      isSecondary: true,
                      height: 44,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TangibleButton(
                      text: L10n.t('Shop', 'වෙළඳසැල'),
                      icon: Icons.shopping_cart_rounded,
                      height: 44,
                      backgroundColor: AppColors.accent,
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopView()));
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.headingDark)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 12.5, color: AppColors.subtext)),
        ],
      ),
    );
  }
}
