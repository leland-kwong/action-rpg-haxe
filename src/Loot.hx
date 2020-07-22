typedef LootDefType = String;

typedef LootDefCat = String;

typedef LootDef = {
  name: String,
  type: LootDefType,
  category: LootDefCat,
  minDamage: Int,
  maxDamage: Int,
  spriteKey: String
};

// loot that was generated via rng
typedef LootInstance = {
  type: LootDefType
};

class Loot {
  static final lootDefinitions: Array<LootDef> = [
  {
    name: 'Spider Bots',
    type: 'spiderBots',
    category: 'ability',
    minDamage: 1,
    maxDamage: 1,
    spriteKey: 'ui/loot__ability_spider_bot'
  }
  ];

  static final defs: Map<LootDefType, LootDef> = [
    for (def in lootDefinitions) def.type => def
  ];

  public static function getDef(type): LootDef {
    return defs.get(type);
  }
}
