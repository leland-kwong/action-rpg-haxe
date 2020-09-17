import Grid.GridRef;

typedef EntityId = String;

typedef EntityComponents = Map<String, Dynamic>;

typedef EntityProps = {
  var x: Float;
  var y: Float;
  var ?stats: EntityStats.StatsRef;
  var ?type: String;
  var ?radius: Int;
  var ?avoidanceRadius: Int;
  var ?id: EntityId;
  var ?sightRange: Int;
  var ?components: EntityComponents;
}

class Cooldown {
  var cds: Map<String, Float>;

  public static final defaultCooldown = new Cooldown();

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

  public static function get(ref: Cooldown, key): Float {
    if (ref == null) {
      return 0;
    }

    final v = ref.cds.get(key);

    return v == null ? 0 : v;
  }

  public static function update(ref: Cooldown, dt: Float) {
    if (ref == null) {
      return;
    }

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
  static final defaultComponents: Map<String, Dynamic> = [
    'neighborQueryThreshold' => 10,
    'neighborCheckInterval' => 1,
    'alpha' => 1,
    'speed' => {
      type: 'MOVESPEED_MODIFIER',
      value: 0
    },
    'aiType' => 'UNKNOWN_AI_TYPE',

    // used to indicate an entity is behind an obstacle such as a tall wall which enables an entity to render a silhouette.
    'isObscured' => false,
    'isObscuring' => false,
  ];
  public final showHitNumbers = true;
  public static var NULL_ENTITY: Entity = {
    final defaultEntity = new Entity({
      x: 0, 
      y: 0, 
      radius: 0,
      id: 'NULL_ENTITY',
      type: 'NULL_ENTITY'
    }, true);
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
  public var avoidOthers = false;
  public var forceMultiplier = 1.0;
  public var status = 'TARGETABLE';
  public var deathAnimationStyle = 'default';
  public var cds = Cooldown.defaultCooldown;
  public var traversableGrid: GridRef;
  public var obstacleGrid: GridRef;
  public var stats: EntityStats.StatsRef;
  public var components: EntityComponents;
  public final createdAt = Main.Global.time;
  public var renderFn: (ref: Entity, time: Float) -> Void;
  public var onDone: (ref: Entity) -> Void;
  public var facingDir = 1;
 
  public function new(
      props: EntityProps, 
      fromInitialization = false) {
 
    id = props.id == null
      ? 'entity_${idGenerated++}'
      : props.id;

    super();

    radius = Utils.withDefault(
        props.radius, radius);
    type = Utils.withDefault(
        props.type, type);
    stats = Utils.withDefault(
        props.stats, EntityStats.placeholderStats);
    x = props.x;
    y = props.y;
    components = {
      final c = props.components != null 
        ? props.components
        : new Map();
      
      c;
    }
    cds = new Cooldown();
    avoidanceRadius = Utils.withDefault(
        props.avoidanceRadius, radius);

    if (fromInitialization) {
      return;
    }

    ALL_BY_ID.set(id, this);
  }

  public static function setComponent<T>(
      ref: Entity, 
      type: String, 
      value: T): T {

    if (value == null) {
      ref.components.remove(type);
    } else {
      ref.components.set(type, value);
    }

    return value;
  }

  public static function setWith<T, T2>(
      ref: Entity,
      component: String,
      calcNextValue: (
        curVal: T, 
        ctx: T2) -> T,
      ?context: T2): T {

    final curVal = getComponent(ref, component); 
    return setComponent(
        ref, component, calcNextValue(curVal, context));
  }

  public static function getComponent(
      ref: Entity, 
      type: String,
      ?defaultValue: Dynamic): Dynamic {

    final value = ref.components.get(type);

    if (value == null) {
      final _default = defaultValue == null
        ? defaultComponents.get(type)
        : defaultValue;

#if debugMode
      final isMissingDefault = _default == null;
      if (isMissingDefault) {
        throw new haxe.Exception(
            '[ecs] default component `${type}` missing');
      }
#end

      return _default;
    }

    return value;
  }

  public static function hasComponent(
      ref: Entity,
      type: String) {

    return ref.components.exists(type);
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

    EntityStats.update(
        stats,
        dt);

    if (showHitNumbers 
        && stats.damageTaken > 0) {
      final font = Fonts.primary().clone();
      font.resizeTo(8);
      final tf = new h2d.Text(
          font,
          Main.Global.scene.particle);
      final initialX = x;
      final initialY = y;
      final endX = x + Utils.irnd(-10, 10, true);
      final endY = y + Utils.irnd(5, 15) * -1;
      final angle = Math.atan2(
          endY - y,
          endX - x);
      tf.textAlign = Center;
      tf.text = Std.string(stats.damageTaken);
      tf.dropShadow = {
        dx: 0.,
        dy: 1.,
        color: 0x000000,
        alpha: 1.
      };

      final startTime = Main.Global.time;
      final duration = 0.5;
      Main.Global.hooks.update.push((dt) -> {
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

    final max = 1;
    final totalSpeed = stats.moveSpeed;

    if (dx != 0) {
      final nextPos = x + Utils.clamp(dx, -max, max) 
        * totalSpeed * dt;
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
        * totalSpeed * dt;
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
    return stats.currentHealth <= 0;
  }

  public static function exists(id: EntityId) {
    return getById(id) != NULL_ENTITY;
  }

  // marks the entity for cleanup on the next update 
  public static function destroy(id: EntityId) {
    final ref = Entity.getById(id);
    EntityStats.addEvent(
        ref.stats, 
        EntityStats.destroyEvent,
        false,
        true);
  }

  // immediately cleans up the entity and removes
  // all references
  public static function deAlloc(id: EntityId) {
    destroy(id);
    final a = Entity.getById(id);
    a.remove();
    Entity.ALL_BY_ID.remove(a.id);
    Grid.removeItem(Main.Global.grid.dynamicWorld, a.id);
    Grid.removeItem(Main.Global.grid.obstacle, a.id);
    Grid.removeItem(Main.Global.grid.lootCol, a.id);
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

  static final outlineOffsets = [
    [-1, 0],
    [0, -1],
    [1, 0],
    [0, 1],
  ];
  public static function renderOutline(
      sortOrder: Float, spriteKey, ref: Entity) {
    for (o in outlineOffsets) {
      final ox = o[0];
      final oy = o[1];
      final p = Main.Global.sb.emitSprite(
          ref.x + ox, 
          ref.y + oy,
          spriteKey,
          null,
          null,
          SpriteBatchSystem.emitOptionsNoShadow);

      p.sortOrder = sortOrder - 1;
      p.r = 150;
      p.g = 150;
      p.b = 150;
      p.scaleX = ref.facingDir * 1;
    }
  }

  public static function canInteract(
      entityA: Entity, entityB: Entity, minDist: Float) {

    final distBetweenEntities = Utils.distance(
        entityA.x, entityA.y,
        entityB.x, entityB.y);

    return distBetweenEntities <= minDist;
  }

  public static function debugBox(
      x, y, 
      width, 
      height,
      ?batch: SpriteBatchSystem) {

    final sb = batch == null
      ? Main.Global.sb
      : batch;
    final sprite = sb.emitSprite(
        x, y,
        'ui/square_white');
    sprite.scaleX = width;
    sprite.scaleY = height;

    return sprite;
  };

  public static function unitTests() {
    TestUtils.assert(
        'de-allocate entity',
        (passed) -> {
          final ref = new Entity({
            x: 0,
            y: 0,
          });
          final id = ref.id;

          Entity.deAlloc(id);

          passed(
              !Entity.exists(id)
              && !Entity.ALL_BY_ID.exists(id)
              && ref.parent == null
              && ref.isDone());
        });

    TestUtils.assert(
        'entities have unique ids between instances',
        (passed) -> {
          final ref1 = new Entity({
            x: 0,
            y: 0,
          });
          final ref2 = new Entity({
            x: 0,
            y: 0
          });

          passed(ref1.id != ref2.id);
        });
  }
}
