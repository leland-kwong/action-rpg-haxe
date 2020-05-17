using hxd.Event;
import Fonts;

class Utils {
  public static function distanceSqr(ax:Float,ay:Float,bx:Float,by:Float) : Float {
    return (ax-bx)*(ax-bx) + (ay-by)*(ay-by);
  }

  public static function distance(ax:Float,ay:Float, bx:Float,by:Float) : Float {
    return Math.sqrt( distanceSqr(ax,ay,bx,by) );
  }

  public static function rnd(min:Float, max:Float, ?sign=false) {
    if( sign )
      return (min + Math.random()*(max-min)) * (Std.random(2)*2-1);
    else
      return min + Math.random()*(max-min);
  }

  public static function irnd(min:Int, max:Int, ?sign:Bool) {
    if( sign )
      return (min + Std.random(max-min+1)) * (Std.random(2)*2-1);
    else
      return min + Std.random(max-min+1);
  }
}
typedef Point = {
  var x : Float;
  var y : Float;
  var radius: Int;
  var weight: Float;
  var color: Int;
}

class Colors {
  public static final red = 0xef476f;
  public static final orange = 0xf78c6b;
  public static final yellow = 0xffd166;
  public static final green = 0x06d6a0;
  public static final blue = 0x118ab2;
  public static final darkBlue = 0x073b4c;
  public static final pureWhite = 0xffffff;
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
  public var id: Int;
  public var type: String;
  public var radius: Int;
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
  var time = 0.0;

  public function new(props: Point) {
    super();

    x = props.x;
    y = props.y;
    id = idGenerated++;
    radius = props.radius;
    weight = props.weight;
    color = props.color;

    ALL.push(this);
  }

  public function update(dt: Float) {
    time += dt;

    if (speed != 0) {
      var max = 1;

      if (dx != 0) {
        if (dx > max) {
          dx = max;
        }
        if (dx < -max) {
          dx = -max;
        }
        x += dx * speed * dt;
      }

      if (dy != 0) {
        if (dy > max) {
          dy = max;
        }
        if (dy < -max) {
          dy = -max;
        }
        y += dy * speed * dt;
      }
    }
  }

  public function findNearest(x, y, range, filter: String) {
    var item = null;
    var prevDist = 999999.0;

    for (e in ALL) {
      if (e != this && e.type == filter) {
        var d = Utils.distance(x, y, e.x, e.y);
        if (d <= range && d < prevDist) {
          item = e;
          prevDist = d;
        }
      }
    }

    return item;
  }
}

class Bullet extends Entity {
  var damage = 1;
  var lifeTime = 5.0;

  public function new(
    x1: Float, y1: Float, x2: Float, y2: Float,
    color: Int,
    speed: Float
  ) {
    super({
      x: x1,
      y: y1,
      radius: 10,
      color: color,
      weight: 0.0,
    });
    this.speed = speed;
    forceMultiplier = 0.0;

    var sprite = new h2d.Graphics();
    addChild(sprite);

    sprite.beginFill(0xFFFFFF);
    sprite.drawCircle(0, 0, radius);
    sprite.endFill();

    var aToTarget = Math.atan2(y2 - y1, x2 - x1);
    var _dx = Math.cos(aToTarget);
    var _dy = Math.sin(aToTarget);
    var magnitude = Math.sqrt(_dx * _dx + _dy * _dy);
    var dxNormalized = magnitude == 0 ? _dx : _dx / magnitude;
    var dyNormalized = magnitude == 0 ? _dy : _dy / magnitude;
    dx = dxNormalized;
    dy = dyNormalized;
  }

  public override function update(dt: Float) {
    super.update(dt);

    lifeTime -= dt;

    if (lifeTime <= 0) {
      health = 0;
    }

    for (a in Entity.ALL) {
      if (a.type == 'ENEMY') {
        var d = Utils.distance(x, y, a.x, a.y);
        var min = radius + a.radius * 1.0;
        var isConflict = d < min;
        if (isConflict) {
          health = 0;
          a.damageTaken += damage;
          break;
        }
      }
    }
  }
}

class Turret extends Entity {
  var cds: Cooldown;
  var range = 300;
  var lifeTime = 10.0;
  var attackRate = 0.2;
  var attackVelocity = 500.0;
  var sprite: h2d.Graphics;

  public function new(x, y) {
    super({
      x: x,
      y: y,
      radius: 20,
      color: 0xff6392,
      weight: 0.0,
    });
    type = 'TURRET';
    health = 3;
    cds = new Cooldown();

    sprite = new h2d.Graphics(this);
    sprite.beginFill(color);
    sprite.drawCircle(0, 0, radius);
    sprite.endFill();
  }

  public override function update(dt: Float) {
    super.update(dt);

    cds.update(dt);

    if (!cds.has('attack')) {
      cds.set('attack', attackRate);

      var nearest = findNearest(x, y, range, 'ENEMY');
      if (nearest != null && nearest.status == 'TARGETABLE') {
        var b = new Bullet(
          x, y, nearest.x, nearest.y,
          color,
          attackVelocity
        );
        parent.addChild(b);
      }
    }

    lifeTime -= dt;
    var isDisposed = lifeTime <= 0;
    if (isDisposed) {
      health = 0;
    }

    {
      if (!cds.has('hitFlash')) {
        sprite.color.set(1, 1, 1, 1);
      }

      if (damageTaken > 0) {
        cds.set('hitFlash', 0.04);
        sprite.color.set(255, 255, 255, 1);
        health -= damageTaken;
        damageTaken = 0;
      }
    }
  }
}

class Enemy extends Entity {
  static var healthBySize = [
    1 => 5,
    2 => 10,
    3 => 20,
  ];
  static var speedBySize = [
    1 => 450.0,
    2 => 160.0,
    3 => 100.0,
  ];

  var font: h2d.Font = Fonts.primary.get().clone();
  var text: h2d.Text;
  var cds: Cooldown;
  var damage = 1;
  var follow: Entity;
  var hasSnakeMotion: Bool;
  var spawnDuration: Float;
  var graphic: h2d.Graphics;
  var size: Int;
  var repelFilter: String;
  var attacksTurrets = false;
  public var attackTarget: Entity;

  public function new(props, size, followTarget: Entity) {
    super(props);
    type = 'ENEMY';
    status = 'UNTARGETABLE';
    speed = 0.0;
    spawnDuration = size * 0.2;
    health = healthBySize[size];
    hasSnakeMotion = size == 1;
    avoidOthers = true;
    cds = new Cooldown();
    follow = followTarget;
    this.size = size;
    if (size == 2) {
      attacksTurrets = true;
    }
    if (size == 3) {
      repelFilter = 'TURRET';
    }

    cds.set('summoningSickness', 1.0);
    setScale(0);

    graphic = new h2d.Graphics(this);
    // make outline
    graphic.beginFill(0x000000);
    graphic.drawCircle(0, 0, radius + 1);
    graphic.beginFill(color);
    graphic.drawCircle(0, 0, radius);
    graphic.endFill();

    font.resizeTo(24);
    text = new h2d.Text(font);
    text.textAlign = Center;
    text.textColor = 0x000000;
    // vertical align center
    text.y = -text.textHeight / 2;
    addChild(text);
  }

  public override function update(dt) {
    dx = 0.0;
    dy = 0.0;

    var spawnProgress = Math.min(1, time / spawnDuration);
    var isFullySpawned = spawnProgress >= 1;
    if (!isFullySpawned) {
      setScale(spawnProgress);
    }
    if (isFullySpawned) {
      status = 'TARGETABLE';
      speed = speedBySize[size];
    }

    super.update(dt);

    cds.update(dt);
    text.text = '${health}';

    if (!cds.has('attack')) {
      // distance to keep from destination
      var threshold = follow.radius + 20;
      var attackRange = 80;

      var dFromTarget = Utils.distance(x, y, follow.x, follow.y);
      // exponential drop-off as agent approaches destination
      var speedAdjust = Math.max(0,
                                Math.min(1,
                                          Math.pow((dFromTarget - threshold) / threshold, 2)));
      if (dFromTarget > threshold) {
        var aToTarget = Math.atan2(follow.y - y, follow.x - x);
        dx += Math.cos(aToTarget) * speedAdjust;
        dy += Math.sin(aToTarget) * speedAdjust;
      }

      if (avoidOthers) {
        // make entities avoid each other by repulsion
        for (o in Entity.ALL) {
          if (o != this && o.forceMultiplier > 0) {
            var pt = this;
            var ept = o;
            var d = Utils.distance(pt.x, pt.y, ept.x, ept.y);
            var separation = 5 + Math.sqrt(speed / 2);
            var min = pt.radius + ept.radius + separation;
            var isColliding = d < min;
            if (isColliding) {
              var conflict = min - d;
              var adjustedConflict = Math.min(conflict, conflict * 50 / speed);
              var a = Math.atan2(ept.y - pt.y, ept.x - pt.x);
              var w = pt.weight / (pt.weight + ept.weight);
              // immobile entities have a stronger influence (obstacles such as walls, etc...)
              var multiplier = ept.forceMultiplier;
              var avoidX = Math.cos(a) * adjustedConflict * w * multiplier;
              var avoidY = Math.sin(a) * adjustedConflict * w * multiplier;

              dx -= avoidX;
              dy -= avoidY;

              if (repelFilter == o.type) {
                o.x += avoidX;
                o.y += avoidY;
              }
            }

            if (attackTarget == null) {
              var attackDistance = d - pt.radius + ept.radius;
              if (attackDistance <= attackRange &&
                (
                  o == follow ||
                  (attacksTurrets && o.type == 'TURRET')
                )
              ) {
                // trace('attackTarget', o.type);
                attackTarget = o;
              }
            }
          }
        }
      }

      var max = 1;
      if (dx > max) {
        dx = max;
      }
      if (dx < -max) {
        dx = -max;
      }
      if (dy > max) {
        dy = max;
      }
      if (dy < -max) {
        dy = -max;
      }

      var waveVal = hasSnakeMotion
        ? Math.abs(Math.sin(time * 2.5))
        : 1;
      x += dx * speed * dt * waveVal;
      y += dy * speed * dt * waveVal;
    }

    if (!cds.has('summoningSickness') && attackTarget != null) {
      if (!cds.has('attack')) {
        cds.set('attack', 0.5);
        attackTarget.damageTaken += damage;
      }
    }

    for (child in iterator()) {
      var c:Dynamic = child;

      if (Type.getClass(child) == h2d.Graphics) {
        if (!cds.has('hitFlash')) {
          c.color.set(1, 1, 1, 1);
        }

        if (damageTaken > 0) {
          cds.set('hitFlash', 0.04);
          c.color.set(255, 255, 255, 1);
          health -= damageTaken;
          damageTaken = 0;
        }
      }
    }

    attackTarget = null;
  }
}

class Player extends Entity {
  public var playerInfo: h2d.Text;
  public var maxNumTurretsAvailable = 4;
  public var numTurretsAvailable = 4;
  public var turretReloadTime = 1.0;
  var cds = new Cooldown();
  var hitFlashOverlay: h2d.Graphics;
  var playerSprite: h2d.Graphics;

  public function new(x, y, s2d: h2d.Scene) {
    super({
      x: x,
      y: y,
      radius: 23,
      weight: 1.0,
      color: Colors.blue,
    });
    type = 'PLAYER';
    health = 10;
    speed = 350.0;
    forceMultiplier = 3.0;

    playerSprite = new h2d.Graphics(this);
    playerSprite.beginFill(color);
    playerSprite.drawCircle(0, 0, radius);
    // make halo
    playerSprite.beginFill(0xffffff, 0.3);
    playerSprite.drawCircle(0, 0, radius + 4);
    playerSprite.endFill();

    hitFlashOverlay = new h2d.Graphics(s2d);
    hitFlashOverlay.beginFill(Colors.red);
    hitFlashOverlay.drawRect(0, 0, s2d.width, s2d.height);
  }

  override function onRemove() {
    hitFlashOverlay.remove();
  }

  public override function update(dt) {
    super.update(dt);
    cds.update(dt);

    // pulsate player for visual juice
    playerSprite.setScale(1 - Math.abs(Math.sin(time * 2.5) / 10));

    if (!cds.has('turretReloading') &&
      numTurretsAvailable < maxNumTurretsAvailable
    ) {
      cds.set('turretReloading', turretReloadTime);
      numTurretsAvailable += 1;
    }

    {
      if (!cds.has('hitFlash')) {
        hitFlashOverlay.color.set(1, 1, 1, 0);
      }

      if (damageTaken > 0) {
        cds.set('hitFlash', 0.02);
        hitFlashOverlay.color.set(1, 1, 1, 0.5);
        health -= damageTaken;
        damageTaken = 0;
      }
    }
  }

  public function useAbility(x1, y1, parent: h2d.Object) {
    if (numTurretsAvailable == 0) {
      // TODO: trigger some sort of warning effect
      // so player gets feedback
      trace('nomore turrets available');
      return;
    }

    if (numTurretsAvailable == maxNumTurretsAvailable) {
      cds.set('turretReloading', 1.0);
    }
    var turret = new Turret(x1, y1);
    numTurretsAvailable -= 1;
    parent.addChild(turret);
  }
}

// Spawns enemies over time
class EnemySpawner {
  static var colors = [
    1 => 0xF78C6B,
    2 => 0xFFD166,
    3 => 0x06D6A0,
  ];

  var enemiesLeftToSpawn: Int;
  var parent: h2d.Object;
  var x: Float;
  var y: Float;
  var target: Entity;
  var spawnInterval = 0.1;
  /**
    FIXME
    Currently `Main.hx` checks for the number of enemies
    remaining before going to the next level. So we need to
    spawn an enemy immediately so there is at least 1 enemy
    exists.
  **/
  var accumulator = 0.1;

  public function new(
    x, y, numEnemies, parent: h2d.Object,
    target: Entity
  ) {
    enemiesLeftToSpawn = numEnemies;
    this.parent = parent;
    this.x = x;
    this.y = y;
    this.target = target;
  }

  public function update(dt: Float) {
    if (enemiesLeftToSpawn <= 0) {
      return;
    }

    accumulator += dt;
    if (accumulator < spawnInterval) {
      return;
    }

    accumulator -= spawnInterval;
    enemiesLeftToSpawn -= 1;

    var size = Utils.irnd(1, 3);
    var radius = 7 + size * 10;
    var posRange = 100;
    var e = new Enemy({
      x: x + Utils.irnd(-posRange, posRange),
      y: y + Utils.irnd(-posRange, posRange),
      radius: radius,
      weight: 1.0,
      color: colors[size],
    }, size, target);
    parent.addChild(e);
  }
}

class Game extends h2d.Object {
  public var level = 0;
  var player: Player;
  var target: h2d.Object;
  var playerInfo: h2d.Text;
  var TARGET_RADIUS = 20.0;
  var targetSprite: h2d.Graphics;
  var useAbilityOnClick: (ev: hxd.Event) -> Void;
  var enemySpawner: EnemySpawner;

  public function isGameOver() {
    return player.health <= 0;
  }

  public function cleanupLevel() {
    // reset game state
    for (e in Entity.ALL) {
      e.health = 0;
    }

    target.remove();
    playerInfo.remove();
    hxd.Window.getInstance()
      .removeEventTarget(useAbilityOnClick);
  }

  override function onRemove() {
    cleanupLevel();
    cleanupDisposedEntities();
  }

  public function newLevel(s2d: h2d.Scene) {
    level += 1;
    enemySpawner = new EnemySpawner(
      s2d.width / 2,
      s2d.height / 2,
      level * Math.round(level /2),
      s2d,
      player
    );
  }

  public function new(
    s2d: h2d.Scene,
    oldGame: Game
  ) {
    super();

    s2d.addChild(this);
    if (oldGame != null) {
      oldGame.cleanupLevel();
    }
    player = new Player(
      300,
      s2d.height / 2,
      s2d
    );
    addChild(player);

    var font: h2d.Font = hxd.res.DefaultFont.get().clone();
    font.resizeTo(24);
    playerInfo = new h2d.Text(font);
    playerInfo.textAlign = Left;
    playerInfo.textColor = 0xffffff;
    playerInfo.x = 10;
    playerInfo.y = 10;
    addChild(playerInfo);

    // mouse pointer
    target = new h2d.Object(this);
    targetSprite = new h2d.Graphics(target);
    targetSprite.beginFill(0xffda3d, 0.3);
    targetSprite.drawCircle(0, 0, TARGET_RADIUS);

    useAbilityOnClick = function(ev: hxd.Event) {
      if (ev.kind == hxd.EventKind.EPush) {
        player.useAbility(ev.relX, ev.relY, this);
      }
    }
    hxd.Window.getInstance()
      .addEventTarget(useAbilityOnClick);
  }

  function movePlayer(player: Entity, dt: Float, s2d: h2d.Scene) {
    var Key = hxd.Key;
    var dx = 0;
    var dy = 0;

    if (Key.isDown(Key.A)) {
      dx = -1;
    }
    if (Key.isDown(Key.D)) {
      dx = 1;
    }
    if (Key.isDown(Key.W)) {
      dy = -1;
    }
    if (Key.isDown(Key.S)) {
      dy = 1;
    }

    var magnitude = Math.sqrt(dx * dx + dy * dy);
    var dxNormalized = magnitude == 0 ? dx : dx / magnitude;
    var dyNormalized = magnitude == 0 ? dy : dy / magnitude;

    player.x += dxNormalized * player.speed * dt;
    player.y += dyNormalized * player.speed * dt;
  }

  function cleanupDisposedEntities() {
    var ALL = Entity.ALL;
    var i = 0;
    while (i < ALL.length) {
      var a = ALL[i];
      var isDisposed = a.health <= 0;
      if (isDisposed) {
        ALL.splice(i, 1);
        a.remove();
      } else {
        i += 1;
      }
    }
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    var ALL = Entity.ALL;

    if (enemySpawner != null) {
      enemySpawner.update(dt);
    }

    {
      playerInfo.text = [
        'health: ${player.health}',
        'turrets available: ${player.numTurretsAvailable}'
      ].join('\n');
    }

    cleanupDisposedEntities();
    for (a in ALL) {
      a.update(dt);
    }

    movePlayer(player, dt, s2d);

    target.x = s2d.mouseX;
    target.y = s2d.mouseY;

    var follow = player;

    function byClosest(a, b) {
      var da = Utils.distance(a.x, a.y, follow.x, follow.y);
      var db = Utils.distance(b.x, b.y, follow.x, follow.y);

      if (da < db) {
        return -1;
      }

      if (da > db) {
        return 1;
      }

      return 0;
    }
    /**
      Sort by closest to furthest so that repelling forces go
      from inside to outside to prevent inner agents from getting
      scrunched up.
    **/
    /**
      TODO: This sorts the entire entity list. We probably want
      to figure out a way to have different collections of agents
      for a more localized sorting.
    **/
    ALL.sort(byClosest);
  }
}