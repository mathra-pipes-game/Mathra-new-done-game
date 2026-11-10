/// Hint reward settings. Change the values here.
class HintConfig {
  HintConfig._();

  /// Free hints every new phone gets once, at the very start.
  static const int startHints = 3;

  /// Every time a player's leaderboard score passes another multiple of this,
  /// they get [hintsPerReward] hints. (400, 800, 1200, ...)
  static const int pointsPerReward = 400;
  static const int hintsPerReward = 3;

  /// Bonus for the player who TAKES the #1 spot on the online leaderboard
  /// (given once per new #1; the player pushed down to #2 gets nothing).
  static const int topReward = 3;

  /// Default WhatsApp number (the web admin panel can override it).
  /// International format, digits only.
  static const String whatsappNumber = '94783756055';
  static const String whatsappDisplay = '+94 78 375 6055';

  /// Your website address (shown in the game's shop).
  static const String webUrl = 'https://mathra-pipes-game.web.app';
}
