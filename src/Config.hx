class Config {
  public static final levelExpRequirements = {
    final xpDiff = 20;
    final maxLevel = 20;
    [
      for (level in 1...(maxLevel + 1)) {
        (Math.pow(level,2) + level) /
          2 * xpDiff - (level * xpDiff);
      }
    ];
  }

  public static final enemyStats: 
    Map<String, {
      experienceReward: Int
    }> = [
      'bat' => {
        experienceReward: 1,
      },
      'botMage' => {
        experienceReward: 2,
      },
      'introLevelBoss' => {
        experienceReward: 20
      }
    ];
}
