/**
  TODO: Add enemy destroyed animation (fade out or explode into pieces?)
**/

import Grid.GridRef;
import Fonts;
import Easing;
import Utils;
import Camera;
import ParticlePlayground;

class SoundFx {
  public static var globalCds = new Cooldown();

  public static function bulletBasic(cooldown = 0.1) {
    if (globalCds.has('bulletBasic')) {
      return;
    }
    globalCds.set('bulletBasic', cooldown);

    var soundResource: hxd.res.Sound = null;

    if(hxd.res.Sound.supportedFormat(Wav)){
      soundResource = hxd.Res.sound_effects.turret_basic;
    }

    if(soundResource != null){
      //Play the music and loop it
      soundResource.play(false, 0.2);
    }
  }
}

typedef Point = {
  var x: Float;
  var y: Float;
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

typedef EntityId = String;

class Entity extends h2d.Object {
  static var idGenerated = 0;

  public static var ALL: Array<Entity> = [];
  public static var ALL_BY_ID: Map<String, Entity> = new Map();
  public var id: EntityId;
  public var type = 'UNKNOWN_TYPE';
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

  public function new(props: Point, customId = null) {
    super();

    x = props.x;
    y = props.y;
    id = customId == null
      ? 'entity_${idGenerated++}'
      : customId;
    radius = props.radius;
    weight = props.weight;
    color = props.color;

    ALL.push(this);
    ALL_BY_ID.set(id, this);
  }

  public function update(dt: Float) {
    time += dt;

    if (speed != 0) {
      var max = 1;

      if (dx != 0) {
        x += Utils.clamp(dx, -max, max) * speed * dt;
      }

      if (dy != 0) {
        y += Utils.clamp(dy, -max, max) * speed * dt;
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

class Projectile extends Entity {
  var damage = 1;
  var lifeTime = 5.0;
  var collidedWith: Entity;
  public var neighbors: Array<EntityId>;

  public function new(
    x1: Float, y1: Float, x2: Float, y2: Float,
    speed = 0.0,
    radius = 10,
    nSegments: Int = null
  ) {
    super({
      x: x1,
      y: y1,
      radius: radius,
      color: color,
      weight: 0.0,
    });
    type = 'PROJECTILE';
    this.speed = speed;
    forceMultiplier = 0.0;

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
    collidedWith = null;

    if (lifeTime <= 0) {
      health = 0;
    }

    for (id in neighbors) {
      var a = Entity.ALL_BY_ID[id];
      if (a.type == 'ENEMY' || a.type == 'OBSTACLE') {
        var d = Utils.distance(x, y, a.x, a.y);
        var min = radius + a.radius * 1.0;
        var conflict = d < min;
        if (conflict) {
          collidedWith = a;
          break;
        }
      }
    }
  }
}

class Bullet extends Projectile {
  var launchSoundPlayed = false;
  var particleSystemRef: ParticlePlayground;
  var particle: Particle;

  public function new(x1, y1, x2, y2, speed, sb) {
    super(x1, y1, x2, y2, speed, 8);
    particleSystemRef = sb;
    particle = sb.emitProjectileGraphics(x1, y1, x2, y2, speed);
    lifeTime = 2.0;
  }

  public override function update(dt: Float) {
    super.update(dt);

    if (!launchSoundPlayed) {
      launchSoundPlayed = true;

      SoundFx.bulletBasic();
    }

    if (collidedWith != null) {
      health = 0;
      collidedWith.damageTaken += damage;
      particleSystemRef.removeProjectile(particle);
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
  var cds: Cooldown;
  var damage = 0;
  public var follow: Entity;
  public var canSeeTarget = true;
  var hasSnakeMotion: Bool;
  var spawnDuration: Float;
  var graphic: h2d.Graphics;
  var size: Int;
  var repelFilter: String;
  var bounceAnimationStartTime = -1.0;
  var debugCenter = false;
  public var sightRange = 400;
  public var neighbors: Array<EntityId>;
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
    if (size == 3) {
      repelFilter = 'TURRET';
    }

    cds.set('summoningSickness', 1.0);
    setScale(0);

    graphic = new h2d.Graphics(this);
    graphic.beginFill(color);
    graphic.drawCircle(0, 0, radius);

    if (debugCenter) {
      graphic.beginFill(0x000000);
      graphic.drawCircle(0, 0, 3);
    }

    graphic.beginFill(0xffffff, 0.1);
    graphic.drawCircle(0, 0, radius - 4);
    graphic.endFill();
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
      bounceAnimationStartTime = bounceAnimationStartTime == -1
        ? time
        : bounceAnimationStartTime;
      status = 'TARGETABLE';
      speed = speedBySize[size];

      // bounce animation (stretch/squash)
      {
        var progress = Easing.progress(bounceAnimationStartTime, time, 1.0);
        var ds = Easing.easeInOut(progress);

        graphic.scaleY = 1 + ds / 6;
        graphic.scaleX = 1 - ds / 6;
        graphic.y = 1 + (1 / 6);

        if (progress >= 1) {
          bounceAnimationStartTime = time;
        }
      }
    }

    super.update(dt);

    cds.update(dt);

    if (!cds.has('attack')) {
      // distance to keep from destination
      var threshold = follow.radius + 20;
      var attackRange = 80;
      var dFromTarget = Utils.distance(x, y, follow.x, follow.y);
      // exponential drop-off as agent approaches destination
      var speedAdjust = Math.max(0,
                                Math.min(1,
                                          Math.pow((dFromTarget - threshold) / threshold, 2)));
      if (canSeeTarget && dFromTarget > threshold) {
        var aToTarget = Math.atan2(follow.y - y, follow.x - x);
        dx += Math.cos(aToTarget) * speedAdjust;
        dy += Math.sin(aToTarget) * speedAdjust;
      }

      if (avoidOthers) {
        // make entities avoid each other by repulsion
        for (oid in neighbors) {
          var o = Entity.ALL_BY_ID.get(oid);
          if (o != this && o.forceMultiplier > 0) {
            var pt = this;
            var ept = o;
            var d = Utils.distance(pt.x, pt.y, ept.x, ept.y);
            var separation = 5 + Math.sqrt(speed / 2);
            var min = pt.radius + ept.radius + separation;
            var isColliding = d < min;
            if (isColliding) {
              var conflict = min - d;
              var adjustedConflict = Math.min(conflict, conflict * 60 / speed);
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
                (o == follow)
              ) {
                attackTarget = o;
              }
            }
          }
        }
      }

      var maxDelta = 1;
      var waveVal = hasSnakeMotion
        ? Math.abs(Math.sin(time * 2.5))
        : 1;
      x += Utils.clamp(dx, -maxDelta, maxDelta) *
        speed * dt * waveVal;
      y += Utils.clamp(dy, -maxDelta, maxDelta) *
        speed * dt * waveVal;
    }

    if (!cds.has('summoningSickness') && attackTarget != null) {
      if (!cds.has('attack')) {
        var attackCooldown = 0.0;
        cds.set('attack', attackCooldown);
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
  var cds = new Cooldown();
  var hitFlashOverlay: h2d.Graphics;
  var playerSprite: h2d.Graphics;
  var rootScene: h2d.Scene;
  var sb: ParticlePlayground;

  public function new(x, y, s2d: h2d.Scene) {
    super({
      x: x,
      y: y,
      radius: 23,
      weight: 1.0,
      color: Colors.green,
    });
    type = 'PLAYER';
    health = 10;
    speed = 350.0;
    forceMultiplier = 3.0;

    rootScene = s2d;
    playerSprite = new h2d.Graphics(this);
    // make halo
    playerSprite.beginFill(0xffffff, 0.3);
    playerSprite.drawCircle(0, 0, radius + 4);
    playerSprite.beginFill(color);
    playerSprite.drawCircle(0, 0, radius);
    playerSprite.endFill();

    hitFlashOverlay = new h2d.Graphics(s2d);
    hitFlashOverlay.beginFill(Colors.red);
    hitFlashOverlay.drawRect(0, 0, s2d.width, s2d.height);
    // make it hidden initially
    hitFlashOverlay.color.set(1, 1, 1, 0);

		sb = new ParticlePlayground();
  }

  function movePlayer() {
    var Key = hxd.Key;

    dx = 0;
    dy = 0;

    // left
    if (Key.isDown(Key.A)) {
      dx = -1;
    }
    // right
    if (Key.isDown(Key.D)) {
      dx = 1;
    }
    // up
    if (Key.isDown(Key.W)) {
      dy = -1;
    }
    // down
    if (Key.isDown(Key.S)) {
      dy = 1;
    }

    var magnitude = Math.sqrt(dx * dx + dy * dy);
    var dxNormalized = magnitude == 0 ? dx : (dx / magnitude);
    var dyNormalized = magnitude == 0 ? dy : (dy / magnitude);

    dx = dxNormalized;
    dy = dyNormalized;
  }

  override function onRemove() {
    hitFlashOverlay.remove();
    sb.dispose();
  }

  public override function update(dt) {
    super.update(dt);
    cds.update(dt);
    sb.update(dt);

    movePlayer();
    // pulsate player for visual juice
    playerSprite.setScale(1 - Math.abs(Math.sin(time * 2.5) / 10));
    useAbility(
      Main.Global.rootScene.mouseX,
      Main.Global.rootScene.mouseY,
      Main.Global.mouse.buttonDown
    );
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

  public function useAbility(x1: Float, y1: Float, ability: Int) {
    switch ability {
      case 0: {
        if (cds.has('primaryAbility')) {
          return;
        }
        var angle = Math.atan2(y1 - y, x1 - x);
        var b = new Bullet(
          x + Math.cos(angle) * 30, 
          y + Math.sin(angle) * 30,
					x1,
					y1,
					800.0,
					sb
        );
        Main.Global.rootScene.addChild(b);
        cds.set('primaryAbility', 1 / 10);
      }
    }
  }
}

// Spawns enemies over time
class EnemySpawner {
  static var colors = [
    1 => Colors.red,
    2 => Colors.orange,
    3 => Colors.yellow,
  ];

  var cds = new Cooldown();
  var enemiesLeftToSpawn: Int;
  var parent: h2d.Object;
  var x: Float;
  var y: Float;
  var target: Entity;
  var spawnInterval = 0.05;
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
    cds.update(dt);

    if (cds.has('recentlySpawned')) {
      return;
    }

    cds.set('recentlySpawned', spawnInterval);
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
  public var level = 15;
  var player: Player;
  var target: h2d.Object;
  var playerInfo: h2d.Text;
  var mapRef: GridRef;
  var dynamicWorldRef: GridRef = Grid.create(64);
  var TARGET_RADIUS = 20.0;
  var targetSprite: h2d.Graphics;
  var enemySpawner: EnemySpawner;

  function calcNumEnemies(level: Int) {
    return level * Math.round(level /2);
  }

  public function isGameOver() {
    return player.health <= 0;
  }

  public function isLevelComplete() {
    for (e in Entity.ALL) {
      // enemies still remain, so level not complete
      if (e.type == 'ENEMY') {
        return false;
      }
    }
    return true;
  }

  public function cleanupLevel() {
    // reset game state
    for (e in Entity.ALL) {
      e.health = 0;
    }

    target.remove();
    playerInfo.remove();
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
      calcNumEnemies(level),
      s2d,
      player
    );
  }

  public function new(
    s2d: h2d.Scene,
    oldGame: Game
  ) {
    super();

    Main.Global.rootScene = s2d;

    Asset.loadMap(
      'test',
      (mapData: GridRef) -> {
        var color = Game.Colors.pureWhite;
        var radius = Math.round(mapData.cellSize / 2);
        var createEnvironmentItems = (x, y, items: Grid.GridItems) -> {
          for (id in items) {
            var padding = 10;
            var wallEnt = new Entity({
              x: x * mapData.cellSize + radius,
              y: y * mapData.cellSize + radius,
              radius: radius + padding,
              weight: 1.0,
              color: color
            }, id);
            wallEnt.type = 'OBSTACLE';
            var wallGraphic = new h2d.Graphics(wallEnt);
            wallGraphic.beginFill(color, 0.5);
            wallGraphic.drawRect(-radius, -radius, radius * 2, radius * 2);
            Main.Global.rootScene.addChild(wallEnt);
          }
        }
        Grid.eachCell(mapData, createEnvironmentItems);
        mapRef = mapData;
      },
      (e) -> {
        trace('error loading game map');
      }
    );

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
    Camera.follow(Main.Global.mainCamera, player);

    var font: h2d.Font = hxd.res.DefaultFont.get().clone();
    font.resizeTo(24);
    playerInfo = new h2d.Text(font);
    playerInfo.textAlign = Left;
    playerInfo.textColor = 0xffffff;
    playerInfo.x = 10;
    playerInfo.y = 10;
    Main.Global.uiRoot
      .addChild(playerInfo);

    // mouse pointer
    target = new h2d.Object(this);
    targetSprite = new h2d.Graphics(target);
    targetSprite.beginFill(0xffda3d, 0.3);
    targetSprite.drawCircle(0, 0, TARGET_RADIUS);
  }

  function cleanupDisposedEntities() {
    var ALL = Entity.ALL;
    var i = 0;
    while (i < ALL.length) {
      var a = ALL[i];
      var isDisposed = a.health <= 0;
      if (isDisposed) {
        ALL.splice(i, 1);
        Entity.ALL_BY_ID.remove(a.id);
        Grid.removeItem(dynamicWorldRef, a.id);
        Grid.removeItem(mapRef, a.id);
        a.remove();
      } else {
        i += 1;
      }
    }
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    var isReady = mapRef != null;

    if (!isReady) {
      return;
    }

    Main.Global.mapRef = mapRef;
    Main.Global.dynamicWorldRef = dynamicWorldRef;

    var ALL = Entity.ALL;

    if (enemySpawner != null) {
      enemySpawner.update(dt);
    }

    SoundFx.globalCds.update(dt);

    {
      playerInfo.text = [
        'health: ${player.health}',
      ].join('\n');
    }

    cleanupDisposedEntities();
    var cellSize = mapRef.cellSize;

    var debugLineOfSight = false;
    var lineOfSightCheck = (entity, x, y, i) -> {
      var isClearPath = Grid.isEmptyCell(mapRef, x, y);
      var isInSightRange = i * cellSize <= entity.sightRange;

      if (!isClearPath || !isInSightRange) {
        entity.canSeeTarget = false;
        return false;
      }

      if (debugLineOfSight) {
        var screenX = x * cellSize;
        var screenY = y * cellSize;
        var c = isClearPath
          ? Game.Colors.pureWhite
          : Game.Colors.red;
        var lineWidth = isClearPath ? 0 : 2;
        Main.Global.debugCanvas.beginFill(c, 0.4);
        Main.Global.debugCanvas.lineStyle(lineWidth, c, 0.8);
        Main.Global.debugCanvas.drawRect(screenX, screenY, cellSize, cellSize);
      }

      return isClearPath;
    }

    for (a in ALL) {
      var shouldFindNeighbors = a.type == 'ENEMY'
        || a.type == 'PROJECTILE';

      if (shouldFindNeighbors) {
        var neighbors: Array<String> = [];
        var nRange = 100;
        var dynamicNeighbors = Grid.getItemsInRect(
          dynamicWorldRef, a.x, a.y, a.radius + nRange, a.radius + nRange
        );
        var obstacleNeighbors = Grid.getItemsInRect(
          mapRef, a.x, a.y, a.radius + nRange, a.radius + nRange
        );
        for (n in dynamicNeighbors) {
          neighbors.push(n);
        }
        for (n in obstacleNeighbors) {
          neighbors.push(n);
        }
        var aWithNeighbors:Dynamic = a;
        aWithNeighbors.neighbors = neighbors;
      }

      // line of sight check
      if (a.type == 'ENEMY') {
        var enemy:Dynamic = a;
        var cellSize = mapRef.cellSize;
        var startGridX = Math.floor(a.x / cellSize);
        var startGridY = Math.floor(a.y / cellSize);
        var targetGridX = Math.floor(enemy.follow.x / cellSize);
        var targetGridY = Math.floor(enemy.follow.y / cellSize);

        enemy.canSeeTarget = true;
        Utils.bresenhamLine(
          startGridX, startGridY, targetGridX, targetGridY, lineOfSightCheck, enemy
        );
      }

      a.update(dt);
      Grid.setItemRect(dynamicWorldRef, a.x, a.y, a.radius, a.radius, a.id);
    }

    target.x = s2d.mouseX;
    target.y = s2d.mouseY;
  }
}
