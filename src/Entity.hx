import Grid.GridRef;

typedef EntityId = String;

typedef EntityProps = {
  var x: Float;
  var y: Float;
  var radius: Int;
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

class Entity extends h2d.Object {
  public static var NULL_ENTITY: Entity = {
    final defaultEntity = new Entity({
      x: 0, 
      y: 0, 
      radius: 0
    }, true);
    defaultEntity.type = 'NULL_ENTITY';
    defaultEntity;
  };
  static var idGenerated = 0;

  public static var ALL_BY_ID: Map<String, Entity> = new Map();
  public var neighbors: Array<EntityId> = [];
  public var id: EntityId;
  public var type = 'UNKNOWN_TYPE';
  public var radius: Int;
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
  public var stats: PlayerStats.StatsRef;
  public final neighborCheckInterval: Int = 2; // after X ticks
  var renderFn: (ref: Entity, time: Float) -> Void;
 
  public function new(
      props: EntityProps, 
      fromInitialization = false) {

    if (fromInitialization) {
      return;
    }
    
    super();

    x = props.x;
    y = props.y;
    id = props.id == null
      ? 'entity_${idGenerated++}'
      : props.id;
    radius = props.radius;
    avoidanceRadius = props.avoidanceRadius != null
      ? props.avoidanceRadius : radius;
    if (props.weight != null) {
      weight = props.weight;
    }

    ALL_BY_ID.set(id, this);
  }

  public function update(dt: Float) {
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
