import Grid.GridRef;

typedef EntityId = String;

typedef EntityProps = {
  var x: Float;
  var y: Float;
  var ?radius: Int;
  var ?avoidanceRadius: Int;
  var ?id: EntityId;
  var ?weight: Float;
  var ?sightRange: Int;
}

class Cooldown {
  var cds: Map<String, Float>;

  public function new() {
    cds = new Map();
  }

  // this automatically handles the null case
  public static function has(ref: Cooldown, key) {
    if (ref == null) {
      return false;
    }

    return ref.cds.exists(key) && ref.cds[key] > 0.0;
  }

  public static function set(ref: Cooldown, key, value) {
    if (ref == null) {
      return;
    }

    ref.cds[key] = value;
  }

  public static function get(ref: Cooldown, key) {
    final v = ref.cds.get(key);

    return v == null ? 0 : v;
  }

  public static function update(ref: Cooldown, dt: Float) {
    final cds = ref.cds;

    for (key => timeRemaining in cds) {
      final newTime = timeRemaining - dt;

      if (newTime <= 0) {
        cds.remove(key);
        continue;
      }

      cds[key] = newTime;
    }
  }
}

/*
   TODO: Dissasociate Entity from h2d.Object.
   Instead, the Entity class should just be standalone so
   we don't inherit all the unecessary fields from h2d.Object
   which also will make serialization easier.
 */
class Entity extends h2d.Object {
  public final showHitNumbers = true;
  public static var NULL_ENTITY: Entity = {
    final defaultEntity = new Entity({
      x: 0, 
      y: 0, 
      radius: 0,
      id: 'NULL_ENTITY'
    }, true);
    defaultEntity.type = 'NULL_ENTITY';
    defaultEntity;
  };
  static var idGenerated = 0;

  public static var ALL_BY_ID: Map<String, Entity> = new Map();
  public var neighbors: Array<EntityId> = [];
  public var id: EntityId;
  public var type = 'UNKNOWN_TYPE';
  public var radius = 0;
  public var avoidanceRadius: Int;
  public var dx = 0.0;
  public var dy = 0.0;
  public var weight = 1.0;
  public var speed = 0.0;
  public var avoidOthers = false;
  public var forceMultiplier = 1.0;
  public var health = 1;
  public var damageTaken = 0;
  public var status = 'TARGETABLE';
  public var cds: Cooldown;
  public var traversableGrid: GridRef;
  public var obstacleGrid: GridRef;
  public var stats: EntityStats.StatsRef;
  var deathAnimationStyle = 'default';
  public var components: Map<String, Dynamic> = [
    'neighborQueryThreshold' => 0
  ];
  public var neighborCheckInterval: Int = 2; // after X ticks
  public final createdAt = Main.Global.time;
  public var renderFn: (ref: Entity, time: Float) -> Void;
  public var onDone: (ref: Entity) -> Void;
 
  public function new(
      props: EntityProps, 
      fromInitialization = false) {
 
    id = props.id == null
      ? 'entity_${idGenerated++}'
      : props.id;

    if (fromInitialization) {
      return;
    }

    super();

    radius = Utils.withDefault(
        props.radius, radius);
    x = props.x;
    y = props.y;
    avoidanceRadius = Utils.withDefault(
        props.avoidanceRadius, radius);
    weight = Utils.withDefault(props.weight, weight);

    ALL_BY_ID.set(id, this);
  }

  public static function setComponent(
      ref: Entity, type: String, value: Dynamic) {

    if (value == null) {
      ref.components.remove(type);
      return;
    }

    ref.components.set(type, value);
  }

  public static function getComponent(
      ref: Entity, type: String) {

    return ref.components.get(type);
  }

  public static function getCollisions(
      sourceEntity: EntityId,
      entities: Array<EntityId>,
      ?collisionFilter) {
  
    final s = getById(sourceEntity);
    final collisions = [];

    for (id in entities) {
      final a = getById(id);
      final shouldCheck = collisionFilter != null
        ? collisionFilter(a)
        : true;

      if (shouldCheck) {
        final d = Utils.distance(s.x, s.y, a.x, a.y);
        final min = s.radius + a.radius * 1.0;
        final conflict = d < min;

        if (conflict) {
          collisions.push(conflict);
        }
      }
    }

    return collisions;
  }

  public function update(dt: Float) {
    if (showHitNumbers 
        && damageTaken > 0) {
      final font = Fonts.primary().clone();
      font.resizeTo(8);
      final tf = new h2d.Text(
          font,
          Main.Global.particleScene);
      final initialX = x;
      final initialY = y;
      final endX = x + Utils.irnd(-10, 10, true);
      final endY = y + Utils.irnd(5, 15) * -1;
      final angle = Math.atan2(
          endY - y,
          endX - x);
      tf.textAlign = Center;
      tf.text = Std.string(damageTaken);
      tf.dropShadow = {
        dx: 0.,
        dy: 1.,
        color: 0x000000,
        alpha: 1.
      };

      final startTime = Main.Global.time;
      final duration = 0.5;
      Main.Global.updateHooks.push((dt) -> {
        final aliveTime = Main.Global.time - startTime;
        final progress = aliveTime / duration;
        final dx = Math.cos(angle) * 5;
        final dy = -Math.sin(angle) * 5;

        tf.x = initialX + dx * Easing.easeOutExpo(progress);
        tf.y = initialY
          - 25 * Easing.easeOutExpo(progress)
          + dy * Easing.easeInExpo(progress); 
        tf.alpha = 1 - Easing.easeInExpo(progress); 
        tf.setScale(1 - Easing.easeInExpo(progress));
        
        if (aliveTime > duration) {
          tf.remove();
          return false;
        }
        return true;
      });
    }

    health -= damageTaken;
    damageTaken = 0;

    final max = 1;
    if (dx != 0) {
      final nextPos = x + Utils.clamp(dx, -max, max) 
        * speed * dt;
      final direction = dx > 0 ? 1 : -1;
      final isTraversable = traversableGrid != null 
        ? Lambda.count(
            Grid.getItemsInRect(
              traversableGrid,
              Math.floor(x + (radius * direction)),
              Math.floor(y),
              1,
              1)) > 0
        : true; 

      if (isTraversable) {
        x = nextPos;
      }
    }

    if (dy != 0) {
      final nextPos = y + Utils.clamp(dy, -max, max) 
        * speed * dt;
      final direction = dy > 0 ? 1 : -1;
      final isTraversable = traversableGrid != null 
        ? Lambda.count(
            Grid.getItemsInRect(
              traversableGrid,
              Math.floor(x),
              Math.floor(y + (radius * direction)),
              1,
              1)) > 0
        : true;

      if (isTraversable) {
        y = nextPos;
      }
    }
  }

  public function render(time: Float) {
    if (renderFn != null) {
      renderFn(this, time);
    }
  }

  public function isDone() {
    return health <= 0;
  }

  override function onRemove() {
    final numItemsToDrop = switch(type) {
      case 'INTERACTABLE_PROP': 
        Utils.rollValues([
            0, 0, 0, 0, 0, 1
        ]);
      case 'ENEMY': 
        Utils.rollValues([
            0, 0, 0, 0, 1, 1, 2
        ]);
      default: 0;
    }

    if (numItemsToDrop > 0) {
      for (_ in 0...numItemsToDrop) {
        final lootPool = Lambda.map(
            Lambda.filter(
              Loot.lootDefinitions,
              (def) -> {
                return def.category == 'ability';
              }),
            (def) -> {
              return def.type;
            });
        final lootInstance = Loot.createInstance(lootPool);
        Game.createLootEntity(
            x + Utils.irnd(5, 10, true), 
            y + Utils.irnd(5, 10, true), 
            lootInstance);
      }
    }

    if (onDone != null) {
      onDone(this);
    }
  }

  public static function destroy(id: EntityId) {
    Entity.getById(id).health = 0;
  }

  public static function getById(
      id: EntityId, 
      ?defaultEntity) {
    final ref = ALL_BY_ID.get(id);

    if (ref == null) {
      return defaultEntity == null 
        ? NULL_ENTITY 
        : defaultEntity;
    }

    return ref;
  }

  public static function isNullId(id: EntityId) {
    return id == NULL_ENTITY.id;
  }
}
