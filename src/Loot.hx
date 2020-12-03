typedef LootDefType = String;

typedef LootDefCat = String;

enum Rarity {
  Normal;
  Magical;
  Rare;
  Legendary;
}

typedef LootDef = {
  name: String,
  energyCost: Float,
  cooldown: Float,
  actionSpeed: Float,
  category: LootDefCat,
  minDamage: Int,
  maxDamage: Int,
  spriteKey: String,
  ?damageMultiplier: Float,
  ?rarity: Rarity,
  ?description: () -> String 
};

// loot that was generated via rng
typedef LootInstance = {
  id: String,
  type: LootDefType
};

class Loot {
  // IMPORTANT: 
  // Once we ship the game, we must be careful about modifying the keys
  // because this lookup table will affect loot from previous versions as well.
  public static final lootDefinitions: Map<LootDefType, LootDef> = [
    /*
       Ability ideas
       
       * teleportation
         Teleports the player to the target location
     */
    'basicBlaster' => {
      name: 'Basic Blaster',
      category: 'ability',
      energyCost: 2,
      cooldown: 0,
      actionSpeed: 1/10,
      minDamage: 1,
      maxDamage: 1,
      spriteKey: 'ui/loot__ability_basic_blaster',
      description: () -> {
        return 'Fires a small blast dealing damage to the first target hit.';
      }
    },
    'basicBlasterEvolved' => {
      name: 'Basic Blaster Evolved',
      category: 'ability',
      energyCost: 3,
      cooldown: 0,
      actionSpeed: 1/10,
      minDamage: 1,
      maxDamage: 1,
      spriteKey: 'ui/loot__ability_basic_blaster_evolved',
      rarity: Legendary
    },
    'spiderBots' => {
      name: 'Spider Bots',
      category: 'ability',
      energyCost: 2,
      cooldown: 0,
      actionSpeed: 2 / 10,
      minDamage: 1,
      maxDamage: 1,
      spriteKey: 'ui/loot__ability_spider_bots',
      description: () -> {
        return 'Releases several small bots that move towards nearby enemies, exploding upon impact.';
      }
    },
    // TODO: Make beam have both an initial energy cost at
    // initial use and then a lower channeling cost. This
    // way you can still burst with the ability while
    // still gaining the benefits of a channeling when
    // desired.
    'channelBeam' => {
      name: 'Laser Beam',
      category: 'ability',
      cooldown: 0,
      actionSpeed: 1/200,
      energyCost: .125,
      minDamage: 1,
      maxDamage: 3,
      spriteKey: 'ui/loot__ability_channel_beam'
    },
    'energyBomb' => {
      name: 'Energy Bomb',
      category: 'ability',
      cooldown: 0.3,
      actionSpeed: 0.15,
      energyCost: 4,
      minDamage: 3,
      maxDamage: 5,
      spriteKey: 'ui/loot__ability_energy_bomb'
    },
    'flameTorch' => {
      name: 'Flame Torch',
      category: 'ability',
      cooldown: 0,
      actionSpeed: 0.25,
      energyCost: 0,
      minDamage: 3,
      maxDamage: 5,
      spriteKey: 'ui/loot__ability_flame_torch'
    },
    'burstCharge' => {
      name: 'Burst Charge',
      category: 'ability',
      cooldown: 0.3,
      actionSpeed: 0.15,
      energyCost: 3,
      minDamage: 3,
      maxDamage: 5,
      spriteKey: 'ui/loot__ability_burst_charge'
    },
    // TODO: Add support for charges
    // where the ability builds charges as you
    // kill enemies.
    'heal1' => {
      name: 'Basic Health Restore',
      category: 'ability',
      cooldown: 0.3,
      actionSpeed: 0,
      energyCost: 0,
      minDamage: 0,
      maxDamage: 0,
      spriteKey: 'ui/loot__ability_heal_1',
      description: () -> {
        return 'Recovers health over a short duration.';
      }
    },
    'energy1' => {
      name: 'Basic Energy Restore',
      category: 'ability',
      cooldown: 0.3,
      actionSpeed: 0,
      energyCost: 0,
      minDamage: 0,
      maxDamage: 0,
      spriteKey: 'ui/loot__ability_energy_1',
      description: () -> {
        return 'Recovers energy over a short duration.';
      }
    },
    'moveSpeedAura' => {
      name: 'Burst Of Speed',
      category: 'ability',
      cooldown: 0,
      actionSpeed: 0,
      energyCost: 0,
      minDamage: 0,
      maxDamage: 0,
      spriteKey: 'ui/loot__ability_movespeed_aura',
      description: () -> {
        return 'Gain an aura granting increased movement speed to you and your allies.';
      }
    },
    'forceField' => {
      name: 'Force Field 1',
      category: 'ability',
      cooldown: 2,
      actionSpeed: 0,
      energyCost: 10,
      minDamage: 0,
      maxDamage: 0,
      spriteKey: 'ui/loot__ability_forcefield',
      description: () -> {
        return 'Creates a temporary shield that absorbs a portion of all incoming damage.';
      }
    },
    'nullItem' => {
      name: 'Null Item',
      category: 'nullCategory',
      cooldown: 0,
      actionSpeed: 0,
      energyCost: 0,
      minDamage: 0,
      maxDamage: 0,
      spriteKey: 'ui/placeholder'
    },
  ];

  public static function getDef(type: LootDefType): LootDef {
    return lootDefinitions.get(type);
  }

  public static function createInstance(
      typesToRoll: Array<LootDefType>,
      ?explicitId: String): LootInstance {

    final rolledType = Utils.rollValues(typesToRoll);
    final instanceId = explicitId != null ? 
      explicitId : Utils.uid();

    return {
      id: instanceId,
      type: rolledType
    };
  }
}
