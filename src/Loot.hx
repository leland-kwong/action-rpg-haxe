typedef LootDefType = String;

typedef LootDefCat = String;

typedef LootDef = {
  name: String,
  type: LootDefType,
  energyCost: Int,
  cooldown: Float,
  category: LootDefCat,
  minDamage: Int,
  maxDamage: Int,
  spriteKey: String,
};

// loot that was generated via rng
typedef LootInstance = {
  id: String,
  type: LootDefType
};

class Loot {
  public static final lootDefinitions: Array<LootDef> = [
    {
      name: 'Basic Blaster',
      type: 'basicBlaster',
      category: 'ability',
      energyCost: 2,
      cooldown: 1 / 10,
      minDamage: 1,
      maxDamage: 1,
      spriteKey: 'ui/loot__ability_basic_blaster',
    },
    {
      name: 'Spider Bots',
      type: 'spiderBots',
      category: 'ability',
      energyCost: 2,
      cooldown: 1 / 5,
      minDamage: 1,
      maxDamage: 1,
      spriteKey: 'ui/loot__ability_spider_bots'
    },
    {
      name: 'Laser Beam',
      type: 'channelBeam',
      category: 'ability',
      cooldown: 0.0001,
      energyCost: 2,
      minDamage: 1,
      maxDamage: 3,
      spriteKey: 'ui/loot__ability_channel_beam'
    },
    {
      name: 'Energy Bomb',
      type: 'energyBomb',
      category: 'ability',
      cooldown: 0.3,
      energyCost: 4,
      minDamage: 3,
      maxDamage: 5,
      spriteKey: 'ui/loot__ability_energy_bomb'
    },
    {
      name: 'Green Arrow Socketable',
      type: 'greenArrowSocketable',
      category: 'socketable',
      cooldown: 0,
      energyCost: 0,
      minDamage: 0,
      maxDamage: 0,
      spriteKey: 'ui/loot__socketable_green_arrow_up'
    },
    {
      name: 'Null Item',
      type: 'nullItem',
      category: 'nullCategory',
      cooldown: 0,
      energyCost: 0,
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
      typesToRoll: Array<LootDefType>,
      ?explicitId: String): LootInstance {

    final rolledType = Utils.rollValues(typesToRoll);
    final id = explicitId != null ? 
      explicitId : Utils.uid();

    return {
      id: id,
      type: rolledType
    };
  }
}
