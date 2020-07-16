typedef EventObject = {
  final type: String;
  final ?value: Dynamic;
  final ?createdAt: Float;
  final ?duration: Float;
}

private typedef RecentEvents = Array<EventObject>;

typedef StatsRef = {
  var maxHealth: Int;
  var maxEnergy: Int;
  var currentHealth: Float;
  var currentEnergy: Float;
  var energyRegeneration: Int; // per second
  var recentEvents: RecentEvents;
  var _damageFromHits: Float;
}

// TODO
// We should rename this since we'll be able to 
// use this this for npcs and enemies as well
class PlayerStats {
  public static function create(props): StatsRef {
    final p = props;

    return {
      maxHealth:     p.maxHealth,
      maxEnergy:     p.maxEnergy,
      currentHealth: p.currentHealth,
      currentEnergy: p.currentEnergy,
      // per second
      energyRegeneration: p.energyRegeneration,
      _damageFromHits: 0.0,
      recentEvents: []
    };
  }

  public static function addEvent(
      statsRef, event: EventObject) {

    statsRef.recentEvents.push(event);
  }

  // run events
  public static function update(
      sr: StatsRef, dt: Float) {

    final events = sr.recentEvents;
    var i = 0;

    // reset any frame-specific information
    {
      sr._damageFromHits = 0.0;
    }

    while (i < events.length) {
      final ev = events[i];
      final done = switch(ev) {
        case { 
          type: 'ENERGY_SPEND', 
          value: v }: {

            final newState = sr.currentEnergy - v;
            sr.currentEnergy = Utils.clamp(
                newState, 0, sr.maxEnergy);
            true;
          }

        case { 
          type: 'DAMAGE_RECEIVED',
          value: v }: {

            sr._damageFromHits += v;
            true;
          }

        case {
          type: 'DOT_DAMAGE',
          value: v,
          createdAt: ca,
          duration: dur }: {

            final newHealth = sr.currentHealth 
              - v * dt;
            sr.currentHealth = Utils.clamp(
                newHealth, 0, sr.maxHealth);

            final aliveTime = Main.Global.time - ca;
            aliveTime > dur; 
          }

        case _:
          false;
      }

      sr.currentHealth -= sr._damageFromHits;

      if (done) {
        events.splice(i, 1);
      } else {
        i += 1;
      }
    }

    // handle regeneration
    final newCurrentEnergy = sr.currentEnergy 
      + sr.energyRegeneration * dt;
    sr.currentEnergy = Utils.clamp(
        newCurrentEnergy, 0, sr.maxEnergy);
  } 
}
