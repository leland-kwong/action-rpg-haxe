import Grid.GridRef;

typedef EntityId = String;

typedef EntityProps = {
  var x: Float;
  var y: Float;
  var radius: Int;
  var ?avoidanceRadius: Int;
  var ?id: EntityId;
  var ?weight: Float;
  var ?color: Int;
  var ?sightRange: Int;
}

class Cooldown {
  var cds: Map<String, Float>;

  public function new() {
    cds = new Map();
  }

  public function set(key, value) {
    cds[key] = value;
  }

  public function has(key) {
    return cds.exists(key) && cds[key] > 0.0;
  }

  public function update(dt: Float) {
    for (key => value in cds) {
      cds[key] = value - dt;
    }
  }
}

class Entity extends h2d.Object {
  static var idGenerated = 0;

  public static var ALL: Array<Entity> = [];
  public static var ALL_BY_ID: Map<String, Entity> = new Map();
  public var neighbors: Array<EntityId>;
  public var id: EntityId;
  public var type = 'UNKNOWN_TYPE';
  public var radius: Int;
  public var avoidanceRadius: Int;
  public var dx = 0.0;
  public var dy = 0.0;
  public var weight = 1.0;
  public var speed = 0.0;
  public var color: Int;
  public var avoidOthers = false;
  public var forceMultiplier = 1.0;
  public var health = 1;
  public var damageTaken = 0;
  public var status = 'TARGETABLE';
  public var cds: Cooldown;
  public var traversableGrid: GridRef;
  public var obstacleGrid: GridRef;

  public function isDone() {
    return health <= 0;
  }

  public function new(props: EntityProps) {
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
    color = props.color;

    ALL.push(this);
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

  public function render(time: Float) {}
}
