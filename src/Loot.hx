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
  id: String,
  type: LootDefType
};

class Loot {
  public static final lootDefinitions: Array<LootDef> = [
  {
    name: 'Green Arrow Socketable',
    type: 'greenArrowSocketable',
    category: 'socketable',
    minDamage: 0,
    maxDamage: 0,
    spriteKey: 'ui/loot__socketable_green_arrow_up'
  },
  {
    name: 'Basic Blaster',
    type: 'basicBlaster',
    category: 'ability',
    minDamage: 0,
    maxDamage: 0,
    spriteKey: 'ui/loot__ability_basic_blaster'
  },
  {
    name: 'Spider Bots',
    type: 'spiderBots',
    category: 'ability',
    minDamage: 1,
    maxDamage: 1,
    spriteKey: 'ui/loot__ability_spider_bot'
  },
  {
    name: 'Null Item',
    type: 'nullItem',
    category: 'nullCategory',
    minDamage: 0,
    maxDamage: 0,
    spriteKey: 'ui/placeholder'
  },
  ];

  static final defs: Map<LootDefType, LootDef> = [
    for (def in lootDefinitions) def.type => def
  ];

  public static function getDef(type): LootDef {
    return defs.get(type);
  }

  public static function createInstance(
      typeIndices: Array<Int>,
      ?explicitId: String): LootInstance {

    final lootDefIndex = Utils.rollValues(typeIndices);
    final id = explicitId != null ? 
      explicitId : Utils.uid();

    return {
      id: id,
      type: lootDefinitions[lootDefIndex].type
    };
  }
}
