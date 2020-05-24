/**
  TODO: Add enemy destroyed animation (fade out or explode into pieces?)
**/

using hxd.Event;
import Fonts;
import Easing;

class SoundFx {
  public static var globalCds = new Cooldown();

  public static function turretBasic(cooldown = 0.1) {
    if (globalCds.has('turretBasic')) {
      return;
    }
    globalCds.set('turretBasic', cooldown);

    var soundResource: hxd.res.Sound = null;

    if(hxd.res.Sound.supportedFormat(Wav)){
      soundResource = hxd.Res.turret_basic;
    }

    if(soundResource != null){
      //Play the music and loop it
      soundResource.play(false, 0.4);
    }
  }

  public static function clusterBombLaunch(cooldown = 0.1) {
    if (globalCds.has('clusterBombLaunch')) {
      return;
    }
    globalCds.set('clusterBombLaunch', cooldown);

    var soundResource: hxd.res.Sound = null;

    if(hxd.res.Sound.supportedFormat(Wav)){
      soundResource = hxd.Res.cluster_bomb_launch;
    }

    if(soundResource != null){
      //Play the music and loop it
      soundResource.play(false);
    }
  }

  public static function clusterBombExplosion(cooldown = 0.1) {
    if (globalCds.has('clusterBombExplosion')) {
      return;
    }
    globalCds.set('clusterBombExplosion', cooldown);

    var soundResource: hxd.res.Sound = null;

    if(hxd.res.Sound.supportedFormat(Wav)){
      soundResource = hxd.Res.cluster_bomb_explosion;
    }

    if(soundResource != null){
      //Play the music and loop it
      soundResource.play(false);
    }
  }
}

class Utils {
  public static function clamp(value: Float, min: Float, max: Float) {
    if (value < min) {
      return min;
    }

    if (value > max) {
      return max;
    }

    return value;
  }

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

  public function new(
    x1: Float, y1: Float, x2: Float, y2: Float,
    color = 0xffffff,
    speed: Float,
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
    this.speed = speed;
    forceMultiplier = 0.0;

    var aToTarget = Math.atan2(y2 - y1, x2 - x1);

    var sprite = new h2d.Graphics();
    addChild(sprite);
    sprite.beginFill(color);
    sprite.drawCircle(0, 0, radius, nSegments);
    sprite.beginFill(color, 0.3);
    sprite.drawCircle(0, 0, radius + 4, nSegments);
    sprite.endFill();

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

    for (a in Entity.ALL) {
      if (a.type == 'ENEMY') {
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

  public function new(x1, y1, x2, y2, color, speed) {
    super(x1, y1, x2, y2, color, speed, 10);
    lifeTime = 2.0;
  }

  public override function update(dt: Float) {
    super.update(dt);

    if (!launchSoundPlayed) {
      launchSoundPlayed = true;

      SoundFx.turretBasic();
    }

    if (collidedWith != null) {
      health = 0;
      collidedWith.damageTaken += damage;
    }
  }
}

class ClusterBombExplosion extends Entity {
  var triggered = false;
  var explosions: Array<Projectile> = [];
  var explosionArea: Int;

  public function new(x, y, radius) {
    super({
      x: x,
      y: y,
      color: Colors.pureWhite,
      weight: 1.0,
      radius: 0
    });
    explosionArea = radius;
  }

  function damageEachAgentInRadius(x, y, radius, damage) {
    // hit all targets in area
    for (a in Entity.ALL) {
      if (a.type == 'ENEMY') {
        var d = Utils.distance(a.x, a.y, x, y);
        var min = a.radius + radius;
        var conflict = d < min;
        if (conflict) {
          a.damageTaken += damage;
        }
      }
    }
  }

  public override function update(dt: Float) {
    super.update(dt);

    var explosionDuration = 0.5;
    var progress = Easing.progress(0, time, explosionDuration);
    var sx = Easing.easeIn(progress);
    if (progress >= 1) {
      health = 0;
      return;
    }

    if (triggered) {
      // animate explosion
      for (expl in explosions) {
        expl.setScale(1 - sx);
        expl.alpha = 0.8 - sx;
      }
      return;
    }
    triggered = true;

    SoundFx.clusterBombExplosion();

    for (_ in 0...3) {
      var area = explosionArea;
      var x2 = x + Utils.irnd(-area, area);
      var y2 = y + Utils.irnd(-area, area);
      var inst = new Projectile(
        x2, y2, x2, y2, Colors.pureWhite,
        0.0, 45
      );
      Main.Global.rootScene.addChild(inst);
      damageEachAgentInRadius(x2, y2, inst.radius, 1);
      explosions.push(inst);
    }
  }
}

class ClusterBomb extends Projectile {
  var launchSoundPlayed = false;
  var initialExplosionTriggered = false;
  var explosionAreaRadius = 70;

  public function new(x1, y1, x2, y2, color, speed, projectilRadius, explosionAreaRadius) {
    super(x1, y1, x2, y2, color, speed, projectilRadius, 5);
    lifeTime = 2.0;
    this.explosionAreaRadius = explosionAreaRadius;
  }

  public override function update(dt: Float) {
    super.update(dt);

    set_rotation(time * 4);

    if (!launchSoundPlayed) {
      launchSoundPlayed = true;
      SoundFx.clusterBombLaunch();
    }

    var shouldExplode = collidedWith != null ||
      time >= lifeTime;
    if (shouldExplode) {
      health = 0;

      Main.Global.rootScene.addChild(
        new ClusterBombExplosion(x, y, explosionAreaRadius)
      );
    }
  }
}

class Turret extends Entity {
  public static var baseColor = Colors.green;
  var cds: Cooldown;
  var range = 300;
  var lifeTime = 10.0;
  var attackRate = 0.2;
  var attackVelocity = 500.0;
  var sprite: h2d.Graphics;
  var attackType = 'Bullet';

  public function new(x, y, attackType) {
    super({
      x: x,
      y: y,
      radius: 20,
      color: Turret.baseColor,
      weight: 0.0,
    });
    type = 'TURRET';
    this.attackType = attackType;
    health = 3;
    cds = new Cooldown();

    var nSegments = -1;

    if (attackType == 'ClusterBomb') {
      nSegments = 5;
      attackRate = 1.0;
      attackVelocity = 200.0;
      range = 400;
    }

    sprite = new h2d.Graphics(this);
    sprite.beginFill(color);
    sprite.lineStyle(0);
    sprite.drawCircle(0, 0, radius, nSegments);
    sprite.endFill();
  }

  public override function update(dt: Float) {
    super.update(dt);

    cds.update(dt);

    var nearest = findNearest(x, y, range, 'ENEMY');
    if (nearest != null && nearest.status == 'TARGETABLE') {
      var angleToTarget = Math.atan2(nearest.y - y, nearest.x - x);
      set_rotation(angleToTarget);

      if (!cds.has('attack')) {
        cds.set('attack', attackRate);
        switch attackType {
          case 'ClusterBomb': {
            var b = new ClusterBomb(
              x, y, nearest.x, nearest.y,
              Colors.pureWhite,
              attackVelocity,
              10,
              70
            );
            Main.Global.rootScene.addChild(b);
          }
          case 'Bullet': {
            var b = new Bullet(
              x, y, nearest.x, nearest.y,
              Colors.pureWhite,
              attackVelocity
            );
            Main.Global.rootScene.addChild(b);
          }
        }
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
  var cds: Cooldown;
  var damage = 1;
  var follow: Entity;
  var hasSnakeMotion: Bool;
  var spawnDuration: Float;
  var graphic: h2d.Graphics;
  var size: Int;
  var repelFilter: String;
  var attacksTurrets = false;
  var bounceAnimationStartTime = -1.0;
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
    graphic.beginFill(color);
    graphic.drawCircle(0, 0, radius);
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
                (
                  o == follow ||
                  (attacksTurrets && o.type == 'TURRET')
                )
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
  var rootScene: h2d.Scene;

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
  }

  function movePlayer() {
    var Key = hxd.Key;

    dx = 0;
    dy = 0;

    // left
    if (Key.isDown(Key.A) && x > radius) {
      dx = -1;
    }
    // right
    if (Key.isDown(Key.D) && x < rootScene.width - radius) {
      dx = 1;
    }
    // up
    if (Key.isDown(Key.W) && y > radius) {
      dy = -1;
    }
    // down
    if (Key.isDown(Key.S) && y < rootScene.height - radius) {
      dy = 1;
    }

    var magnitude = Math.sqrt(dx * dx + dy * dy);
    var dxNormalized = magnitude == 0 ? dx : dx / magnitude;
    var dyNormalized = magnitude == 0 ? dy : dy / magnitude;

    dx = dxNormalized;
    dy = dyNormalized;
  }

  override function onRemove() {
    hitFlashOverlay.remove();
  }

  public override function update(dt) {
    super.update(dt);
    cds.update(dt);

    movePlayer();
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

  public function useAbility(x1, y1, ability: Int, parent: h2d.Object) {
    if (numTurretsAvailable == 0) {
      // TODO: trigger some sort of warning effect
      // so player gets feedback
      trace('nomore turrets available');
      return;
    }

    if (numTurretsAvailable == maxNumTurretsAvailable) {
      cds.set('turretReloading', 1.0);
    }

    numTurretsAvailable -= 1;
    switch ability {
      case 0: {
        var turret = new Turret(x1, y1, 'Bullet');
        parent.addChild(turret);
      }
      case 1: {
        var turret = new Turret(x1, y1, 'ClusterBomb');
        parent.addChild(turret);
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

    Main.Global.rootScene = s2d;
    hxd.Res.initEmbed();

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
        player.useAbility(ev.relX, ev.relY, ev.button, this);
      }
    }
    hxd.Window.getInstance()
      .addEventTarget(useAbilityOnClick);
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

    SoundFx.globalCds.update(dt);

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

    target.x = s2d.mouseX;
    target.y = s2d.mouseY;
  }
}
