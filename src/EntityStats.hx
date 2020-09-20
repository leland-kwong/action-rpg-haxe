typedef EventObject = {
  final type: String;
  final ?value: Dynamic;
  final ?createdAt: Float;
  final ?duration: Float;
}

private typedef StatsEventsList = Array<EventObject>;

typedef InitialStats = {
  var currentHealth: Float;
  var ?maxHealth: Float;
  var ?maxEnergy: Float;
  var ?currentEnergy: Float;
  // per second
  var ?energyRegeneration: Int;
  var ?label: String;
  var ?pickupRadius: Int;
  var ?lightRadius: Float;
}

typedef ForceFieldRef = {
  life: Float,
  percentAbsorb: Float,
  damageTaken: Float,
}

typedef StatsRef = {
  > InitialStats,

  var label: String;
  var damageTaken: Float;
  var moveSpeed: Float;
  var forceField: ForceFieldRef;
  // base damage that the entity deals
  var damage: Float;
  var recentEvents: StatsEventsList;
};

class EntityStats {
  public static function create(props: InitialStats): StatsRef {
    final p = props;

    return {
      label:              p.label,
      maxHealth:          Utils.withDefault(
                            p.maxHealth, 
                            p.currentHealth),
      maxEnergy:          Utils.withDefault(
                            p.maxEnergy, 
                            p.currentEnergy),
      currentHealth:      p.currentHealth,
      currentEnergy:      p.currentEnergy,
      energyRegeneration: p.energyRegeneration,
      pickupRadius:       p.pickupRadius,
      moveSpeed:          0,
      damageTaken:        0,
      damage:             0,
      lightRadius:        Utils.withDefault(
                            p.lightRadius,
                            0),
      forceField:         {
                            life: 0.,
                            percentAbsorb: 0.,
                            damageTaken: 0.
                          },
      recentEvents:       [],
    };
  }

  public static final placeholderStats = create({
    label: '@placeholder',
    maxHealth: 1,
    maxEnergy: 0,
    currentHealth: 1.,
    currentEnergy: 0.,
    energyRegeneration: 0,
    pickupRadius: 0,
  });

  public static final destroyEvent: EventObject = {
    type: 'DESTROY'
  };

  public static function addEvent(
      statsRef: StatsRef, 
      event: EventObject, 
      ?after = false,
      ?applyImmediate = false) {

    // put event at end of list because
    // it depends on previous events
    if (after) {
      statsRef.recentEvents.push(event);
    } else {
      statsRef.recentEvents.unshift(event);
    }

    if (applyImmediate) {
      update(statsRef, 0);
      return;
    }
  }

  // run events
  public static function update(
      sr: StatsRef, dt: Float) {

    final nextRecentEvents = [];
    var velocity = 0.;
    var totalDamageTaken = 0.;
    var flatDamageBuff = 0.;
    var damageMultiplier = 1.;

    for (ev in sr.recentEvents) {
      final done = switch(ev) {
        case {
          type: 'DESTROY'
        }: {
          sr.currentHealth = 0;
          true;
        }

        case { 
          type: 'ENERGY_SPEND', 
          value: v }: {

            final newState = sr.currentEnergy - v;
            sr.currentEnergy = Utils.clamp(
                newState, 0, sr.maxEnergy);
            true;
          }

        case { 
          type: 'FLAT_DAMAGE_INCREASE',
          value: v }: {

            flatDamageBuff += v;
            true;
          }

        case { 
          type: 'PERCENT_DAMAGE_INCREASE',
          value: v }: {

            damageMultiplier += v;
            true;
          }

        case { 
          type: 'DAMAGE_RECEIVED',
          value: v }: {

            final baseDamage: Float = v.baseDamage;
            final sourceDmg: Float = v.sourceStats.damage;
            final totalDamage = (baseDamage + sourceDmg);

            totalDamageTaken += totalDamage;
            true;
          }

        case {
          type: 'LIFE_RESTORE',
          value: v,
          createdAt: ca,
          duration: dur }: {

            final newHealth = sr.currentHealth + v * dt;
            sr.currentHealth = Utils.clamp(
                newHealth, 0, sr.maxHealth);
            final aliveTime = Main.Global.time - ca;

            aliveTime > dur; 
          }

        case {
          type: 'ENERGY_RESTORE',
          value: v,
          createdAt: ca,
          duration: dur }: {

            final newEnergy = sr.currentEnergy + v * dt;
            sr.currentEnergy = Utils.clamp(
                newEnergy, 0, sr.maxEnergy);
            final aliveTime = Main.Global.time - ca;

            aliveTime > dur; 
          }

        case {
          type: 'MOVESPEED_MODIFIER',
          value: v }: {
            velocity += v;            
            true;
          }

        case {
          type: 'MAKE_FORCEFIELD',
          value: forceFieldRef
        }: {
          sr.forceField = forceFieldRef;
          true;
        }

        case _:
          throw new haxe.Exception(
              '[stats recentEvent] invalid recentEvent type `${ev.type}`');
      }

      if (!done) {
        nextRecentEvents.push(ev);
      } 
    }

    sr.moveSpeed = velocity;

    // apply damage taken
    final damageAbsorbedByForceField = Math.min(
        sr.forceField.life,
        totalDamageTaken * sr.forceField.percentAbsorb);
    final finalDamage = Math.max(
        0, totalDamageTaken - damageAbsorbedByForceField);
    sr.forceField.life = Math.max(
        0, sr.forceField.life - damageAbsorbedByForceField);
    sr.forceField.damageTaken = damageAbsorbedByForceField;
    sr.currentHealth -= finalDamage;
    sr.damageTaken = finalDamage;

    sr.damage = flatDamageBuff * damageMultiplier;

    // handle regeneration
    final newCurrentEnergy = sr.currentEnergy 
      + sr.energyRegeneration * dt;
    sr.currentEnergy = Utils.clamp(
        newCurrentEnergy, 0, sr.maxEnergy);
    sr.recentEvents = nextRecentEvents;
  } 
}
