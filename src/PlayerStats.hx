// TODO
// We should rename this sinice we'll be able to use this
// this for npcs and enemies as well
class PlayerStats {
  public static function create() {
    var statsRef = {
      modifiers: {},
      maxHealth: 100,
      maxEnergy: 100,
      currentHealth: 100.0,
      currentEnergy: 100.0,
      energyRegeneration: 2, // per second
      recentEvents: []
    };

    return statsRef;
  }

  public static function addEvent(statsRef, event) {
    statsRef.recentEvents.push(event);
  }

  // flush events
  public static function update(statsRef, dt: Float) {
    var events: Array<Dynamic> = statsRef.recentEvents;

    statsRef.recentEvents = [];

    for (e in events) {
      switch(e.type) {
        case 'ENERGY_SPEND': 
          statsRef.currentEnergy += e.value;
      }
    }

    // handle regeneration
    var newCurrentEnergy = statsRef.currentEnergy 
      + statsRef.energyRegeneration * dt;
    statsRef.currentEnergy = Utils.clamp(
        newCurrentEnergy, 0, statsRef.maxEnergy);
  } 
}
