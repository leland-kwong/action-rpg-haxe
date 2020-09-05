import Session;

class Config {
  static final maxLevel = 20; 
  public static final levelExpRequirements = {
    final xpDiff = 20;
    [
      for (level in 1...(maxLevel + 1)) {
        Std.int((Math.pow(level,2) + level) /
          2 * xpDiff - (level * xpDiff));
      }
    ];
  }

  public static final enemyStats: 
    Map<String, {
      experienceReward: Int,
      health: Float,
      speed: EntityStats.EventObject,
      attackRange: Int,
      attackType: String
    }> = [
      'npcTestDummy' => {
        experienceReward: 0,
        health: Math.pow(10, 10),
        speed: {
          type: 'MOVESPEED_MODIFIER',
          value: 0.
        },
        attackRange: 0,
        attackType: 'no_attack'
      },
      'bat' => {
        experienceReward: 1,
        health: 10,
        speed: {
          type: 'MOVESPEED_MODIFIER',
          value: 90.
        },
        attackRange: 30,
        attackType: 'attack_bullet',
      },
      'botMage' => {
        experienceReward: 2,
        health: 20,
        speed: {
          type: 'MOVESPEED_MODIFIER',
          value: 60.
        },
        attackRange: 120,
        attackType: 'attack_bullet'
      },
      'introLevelBoss' => {
        experienceReward: 20,
        health: 100,
        speed: {
          type: 'MOVESPEED_MODIFIER',
          value: 40.
        },
        attackRange: 80,
        attackType: 'attack_bullet'
      },
      'spiderBot' => {
        experienceReward: 0,
        health: 50,
        speed: {
          type: 'MOVESPEED_MODIFIER',
          value: 100.
        },
        attackRange: 13,
        attackType: 'attack_self_detonate'
      }
    ];

  // returns the array index pointing to the level
  // based on `levelExpRequirements`
  public static function calcCurrentLevel(
      experience: Int) {
    final levelIndex = Lambda.findIndex(
        levelExpRequirements,
        (expReq) -> experience < expReq);
    final isMaxLevel = levelIndex == -1;

    return (isMaxLevel 
      ? maxLevel 
      : levelIndex) - 1;
  }
}
