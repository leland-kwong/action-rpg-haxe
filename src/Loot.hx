typedef LootDefKey = String;

typedef LootDef = {
  name: String,
  minDamage: Int,
  maxDamage: Int,
  spriteKey: String
};

typedef LootInstance = {
  type: LootDefKey
};

class Loot {
  static final defs: Map<LootDefKey, LootDef> = [
    'spiderBots' => {
      name: 'Spider Bots',
      minDamage: 1,
      maxDamage: 1,
      spriteKey: 'ui/loot__ability_spider_bot'
    }
  ];

  public static function getDef(type): LootDef {
    return defs.get(type);
  }
}
