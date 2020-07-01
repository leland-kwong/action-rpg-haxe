/**
  TODO: Add enemy destroyed animation (fade out or explode into pieces?)
**/

import Grid.GridRef;
import Fonts;
import Easing;
import Utils;
import Camera;
import ParticlePlayground;

using Lambda;

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
  public static final black = 0x000000;
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
  public var cds: Cooldown;
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
  var cFilter: Array<String>;
  public var neighbors: Array<EntityId>;

  public function new(
    x1: Float, y1: Float, x2: Float, y2: Float,
    speed = 0.0,
    radius = 10,
    collisionFilter,
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
    cFilter = collisionFilter;

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
      if (Lambda.exists(cFilter, (t) -> t == a.type)) {
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

  public function new(
    x1, y1, x2, y2, speed, bulletType, collisionFilter
  ) {
    super(x1, y1, x2, y2, speed, 8, collisionFilter);
    particleSystemRef = Main.Global.sb;
    particle = particleSystemRef
      .emitProjectileGraphics(x1, y1, x2, y2, speed, bulletType);
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
    1 => 180.0,
    2 => 120.0,
    3 => 100.0,
  ];
  static var attackRangeByType = [
    1 => 80,
    2 => 300,
  ];
  static var spriteSheet: h2d.Tile;
  static var spriteSheetData: Dynamic;

  var font: h2d.Font = Fonts.primary.get().clone();
  var damage = 0;
  public var follow: Entity;
  public var canSeeTarget = true;
  var spawnDuration: Float;
  var graphic: h2d.Graphics;
  var size: Int;
  var repelFilter= 'REPEL_NONE';
  var debugCenter = false;
  var idleAnim: h2d.Anim;
  var runAnim: h2d.Anim;
  var facingDir = 1;
  public var sightRange = 400;
  public var neighbors: Array<EntityId>;
  public var attackTarget: Entity;

  public function new(props, size, followTarget: Entity) {
    super(props);

    cds = new Cooldown();

    if (spriteSheet == null) {
      spriteSheet = hxd.Res.sprite_sheet_png.toTile();
      spriteSheetData = Utils.loadJsonFile(hxd.Res.sprite_sheet_json).frames;
    }

    type = 'ENEMY';
    status = 'UNTARGETABLE';
    speed = 0.0;
    spawnDuration = size * 0.2;
    health = healthBySize[size];
    avoidOthers = true;
    cds = new Cooldown();
    follow = followTarget;
    this.size = size;

    cds.set('summoningSickness', 1.0);
    setScale(0);

    if (size == 1) {
      var idleFrames = [
        'enemy-1/idle1',
        'enemy-1/idle2',
        'enemy-1/idle3',
        'enemy-1/idle4',
        'enemy-1/idle5',
        'enemy-1/idle6',
        'enemy-1/idle7',
        'enemy-1/idle8',
        'enemy-1/idle9',
        'enemy-1/idle10',
      ];
      var idleAnimFrames = [];

      for (frameKey in idleFrames) {
        var frameData = Reflect.field(spriteSheetData, frameKey);
        var t = spriteSheet.sub(
            frameData.frame.x,
            frameData.frame.y,
            frameData.frame.w,
            frameData.frame.h
            ).center();
        t.dy = -frameData.frame.h * frameData.pivot.y;
        idleAnimFrames.push(t);
      }
      idleAnim = new h2d.Anim(idleAnimFrames, 10, this);
      idleAnim.scaleY = 4;

      runAnim = idleAnim;
    }

    if (size == 2) {
      var idleFrames = [
        'enemy-2/idle1',
        'enemy-2/idle2',
      ];
      var idleAnimFrames = [];

      for (frameKey in idleFrames) {
        var frameData = Reflect.field(spriteSheetData, frameKey);
        var t = spriteSheet.sub(
            frameData.frame.x,
            frameData.frame.y,
            frameData.frame.w,
            frameData.frame.h
        ).center();
        t.dy = -frameData.frame.h * frameData.pivot.y;
        idleAnimFrames.push(t);
      }
      idleAnim = new h2d.Anim(idleAnimFrames, 60, this);
      idleAnim.scaleY = 4;

      var runFrames = [
        'enemy-2/move1',
        'enemy-2/move2',
      ];
      var runAnimFrames = [];

      for (frameKey in runFrames) {
        var frameData = Reflect.field(spriteSheetData, frameKey);
        var t = spriteSheet.sub(
          frameData.frame.x,
          frameData.frame.y,
          frameData.frame.w,
          frameData.frame.h
        ).center();
        t.dy = -frameData.frame.h * frameData.pivot.y;
        t.dx = -frameData.frame.w * frameData.pivot.x;
        runAnimFrames.push(t);
      }
      runAnim = new h2d.Anim(runAnimFrames, 60);
      runAnim.scaleY = 4;
    }

    if (debugCenter) {
      graphic = new h2d.Graphics(this);
      graphic.beginFill(0xffffff);
      graphic.drawCircle(0, 0, 3);
    }
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

    if (!cds.has('attack')) {
      // distance to keep from destination
      var threshold = follow.radius + 20;
      var attackRange = attackRangeByType[size];
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
          if (o != this) {
            var pt = this;
            var ept = o;
            var d = Utils.distance(pt.x, pt.y, ept.x, ept.y);

            if (o.forceMultiplier > 0) {
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
            }
          }
        }
      }

      if (canSeeTarget && attackTarget == null) {
        var isInAttackRange = dFromTarget <= attackRange;
        if (isInAttackRange) {
          attackTarget = follow;
        }
      }

      var origX = x;
      var origY = y;
      var maxDelta = 1;
      x += Utils.clamp(dx, -maxDelta, maxDelta) *
        speed * dt;
      y += Utils.clamp(dy, -maxDelta, maxDelta) *
        speed * dt;

      var activeAnim: h2d.Anim = null;

      var hasMovedX = Math.abs(origX - x) >= 0.25;
      var hasMovedY = Math.abs(origY - y) >= 0.25;
      if (runAnim != null && (hasMovedX || hasMovedY)) {
        idleAnim.remove();
        activeAnim = runAnim;
        this.addChild(runAnim);
      }
      else if (idleAnim != null) {
        runAnim.remove();
        activeAnim = idleAnim;
        this.addChild(idleAnim);
      }

      if (activeAnim != null) {
        if (dx != 0) {
          facingDir = (dx > 0 ? -1 : 1);
        }
        activeAnim.scaleX = facingDir * 4;
      }
    }

    // trigger attack
    if (!cds.has('summoningSickness') && attackTarget != null) {
      if (!cds.has('attack')) {
        var attackCooldown = 1.0;
        cds.set('attack', attackCooldown);

        var x2 = follow.x;
        var y2 = follow.y;
        var angle = Math.atan2(y2 - y, x2 - x);
        var b = new Bullet(
          x + Math.cos(angle) * 30,
          y + Math.sin(angle) * 30,
					x2,
					y2,
          300.0,
          'bullet_enemy_large',
          ['PLAYER', 'OBSTACLE']
        );
        Main.Global.rootScene.addChild(b);
      }
    }

    // handle damage
    for (child in iterator()) {
      var c:Dynamic = child;
      var cl = Type.getClass(child);

      if (cl == h2d.Graphics || cl == h2d.Anim) {
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
  var hitFlashOverlay: h2d.Graphics;
  var playerSprite: h2d.Graphics;
  var rootScene: h2d.Scene;
  var runAnim: h2d.Anim;
  var idleAnim: h2d.Anim;
  var attackAnim: h2d.Anim;
  var runAnimFrames: Array<h2d.Tile>;
  var idleAnimFrames: Array<h2d.Tile>;
  var facingX = 1;

  public function new(x, y, s2d: h2d.Scene) {
    super({
      x: x,
      y: y,
      radius: 23,
      weight: 1.0,
      color: Colors.green,
    });
    cds = new Cooldown();
    type = 'PLAYER';
    health = 1000;
    speed = 350.0;
    forceMultiplier = 3.0;

    rootScene = s2d;

    var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
    var spriteSheetData = Utils.loadJsonFile(hxd.Res.sprite_sheet_json).frames;
    var runFrames = [
      'player/run1',
      'player/run2',
      'player/run3',
      'player/run4',
      'player/run5',
      'player/run6',
      'player/run7',
      'player/run8',
    ];
    runAnimFrames = [];

    for (frameKey in runFrames) {
      var frameData = Reflect.field(spriteSheetData, frameKey);
      var t = spriteSheet.sub(
        frameData.frame.x,
        frameData.frame.y,
        frameData.frame.w,
        frameData.frame.h
      ).center();
      t.dy = -frameData.frame.h * frameData.pivot.y;
      runAnimFrames.push(t);
    }
    // creates an animation for these tiles
    runAnim = new h2d.Anim(runAnimFrames, 17);

    var idleFrames = [
      'player/idle'
    ];
    idleAnimFrames = [];
    for (frameKey in idleFrames) {
      var frameData = Reflect.field(spriteSheetData, frameKey);
      var t = spriteSheet.sub(
        frameData.frame.x,
        frameData.frame.y,
        frameData.frame.w,
        frameData.frame.h
      ).center();
      t.dy = -frameData.frame.h * frameData.pivot.y;
      idleAnimFrames.push(t);
    }
    idleAnim = new h2d.Anim(idleAnimFrames);

    var attackSpriteFrames = [
      'player/attack1',
      'player/attack2',
      'player/attack3',
      'player/attack4',
      'player/attack5',
      'player/attack5',
      'player/attack5',
      'player/attack5',
      'player/attack5',
      'player/attack5',
      'player/attack5',
      'player/attack5',
    ];
    var attackAnimFrames = [];
    for (frameKey in attackSpriteFrames) {
      var frameData = Reflect.field(spriteSheetData, frameKey);
      var t = spriteSheet.sub(
        frameData.frame.x,
        frameData.frame.y,
        frameData.frame.w,
        frameData.frame.h
      ).center();
      t.dy = -frameData.frame.h * frameData.pivot.y;
      t.dx = -frameData.frame.w * frameData.pivot.x;
      attackAnimFrames.push(t);
    }
    attackAnim = new h2d.Anim(attackAnimFrames, 60);

    playerSprite = new h2d.Graphics(this);
    // make halo
    playerSprite.beginFill(0xffffff, 0.1);
    playerSprite.drawCircle(0, 0, radius + 4);
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

    if (dx != 0) {
      facingX = dx > 0 ? 1 : -1;
    }

    var magnitude = Math.sqrt(dx * dx + dy * dy);
    var dxNormalized = magnitude == 0 ? dx : (dx / magnitude);
    var dyNormalized = magnitude == 0 ? dy : (dy / magnitude);

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

    var activeAnim;
    if (cds.has('recoveringFromAbility')) {
      activeAnim = attackAnim;
      idleAnim.remove();
      runAnim.remove();
    }
    else {
      attackAnim.remove();
      if (dx != 0 || dy != 0) {
        activeAnim = runAnim;
        idleAnim.remove();
        attackAnim.remove();
      } else {
        activeAnim = idleAnim;
        runAnim.remove();
        attackAnim.remove();
      }
    }
    this.addChild(activeAnim);

    activeAnim.scaleX = 4 * facingX;
    activeAnim.scaleY = 4;
    activeAnim.x = 0;
    activeAnim.y = 0;

    var abilityId = Main.Global.mouse.buttonDown;
    useAbility(
      Main.Global.rootScene.mouseX,
      Main.Global.rootScene.mouseY,
      abilityId
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

  public function useAbility(x2: Float, y2: Float, ability: Int) {
    switch ability {
      case 0: {
        if (cds.has('primaryAbility')) {
          return;
        }
        var abilityCooldown = 1/10;
        cds.set('recoveringFromAbility', abilityCooldown + 0.01);
        attackAnim.currentFrame = 0;

        var angle = Math.atan2(y2 - y, x2 - x);
        var x1 = x + Math.cos(angle) * 30;
        var y1 = y + Math.sin(angle) * 30;
        var b = new Bullet(
          x1,
          y1,
					x2,
					y2,
          800.0,
          'bullet_player_basic',
          ['ENEMY', 'OBSTACLE']
        );
        Main.Global.rootScene.addChild(b);
        cds.set('primaryAbility', abilityCooldown);
      }

      case 1: {
        if (cds.has('ability_2')) {
          return;
        }

        var abilityCooldown = 0;
        var pixelScale = 4;
        var beamThickness = 60;
        var laserHeadSpriteData = Reflect.field(
          Main.Global.sb.pSystem.spriteSheetData,
          'exported/kamehameha_head'
        );
        var laserTailSpriteData = Reflect.field(
          Main.Global.sb.pSystem.spriteSheetData,
          'exported/kamehameha_tail'
        );
        var laserHeadWidth = laserHeadSpriteData.frame.w * pixelScale;
        var laserTailWidth = laserTailSpriteData.frame.w * pixelScale;
        var maxLength = 500;
        cds.set('recoveringFromAbility', abilityCooldown + 0.01);
        var launchOffset = 30;
        var angle = Math.atan2(y2 - y, x2 - x);
        var vx = Math.cos(angle);
        var vy = Math.sin(angle);
        var x1 = x + vx * launchOffset;
        var y1 = y + vy * launchOffset;
        var laserTailX1 = x1 + vx * maxLength;
        var laserTailY1 = y1 + vy * maxLength;
        var yScaleRand = Utils.irnd(0, 1) * 0.5;
        var beamOpacity = (p, progress) -> 1;

        var renderBeam = (startPt, endPt) -> {
          var spriteLifetime = 1/60;
          // laser head
          Main.Global.sb.emitProjectileGraphics(
            startPt.x, startPt.y,
            endPt.x, endPt.y,
            0, 'exported/kamehameha_head',
            spriteLifetime ,
            null,
            (p, progress) -> pixelScale + yScaleRand,
            beamOpacity
          );

          var lcx = startPt.x + (vx * laserHeadWidth);
          var lcy = startPt.y + (vy * laserHeadWidth);
          var beamLength = Utils.distance(lcx, lcy, endPt.x, endPt.y) - laserTailWidth;
          // laser center
          Main.Global.sb.emitProjectileGraphics(
            lcx, lcy,
            endPt.x, endPt.y,
            0, 'exported/kamehameha_center_width_1',
            spriteLifetime,
            (p, progress) -> beamLength,
            (p, progress) -> pixelScale + yScaleRand,
            beamOpacity
          );

          // laser tail
          Main.Global.sb.emitProjectileGraphics(
            endPt.x - (vx * laserTailWidth), endPt.y - (vy * laserTailWidth),
            endPt.x, endPt.y,
            0, 'exported/kamehameha_tail',
            spriteLifetime,
            (p, progress) -> pixelScale + Utils.irnd(0, 1),
            (p, progress) -> pixelScale + yScaleRand,
            beamOpacity
          );
        }

        var dynamicWorldRef = Main.Global.dynamicWorldRef;
        var worldCellSize = dynamicWorldRef.cellSize;
        var cellSize = 10;
        var startGridX = Math.floor(x1 / cellSize);
        var startGridY = Math.floor(y1 / cellSize);
        var targetGridX = Math.floor(laserTailX1 / cellSize);
        var targetGridY = Math.floor(laserTailY1 / cellSize);
        var startPt = new h2d.col.Point(x1, y1);
        var endPt = new h2d.col.Point(laserTailX1, laserTailY1);
        var centerLine = new h2d.col.Line(startPt, endPt);
        var debug = {
          startPos: false,
          queryRects: false,
          endPos: false,
        };

        if (debug.startPos) {
          Main.Global.sb.emitProjectileGraphics(
            laserTailX1, laserTailY1,
            laserTailX1, laserTailY1,
            0, 'exported/square_white',
            0.01,
            (p, progress) -> 10,
            (p, progress) -> 10
          );
        }

        var adjustedEndPt = endPt;

        Utils.bresenhamLine(
          startGridX, startGridY, targetGridX, targetGridY, (ctx, x, y, i) -> {
            var worldX = Math.round(x * cellSize);
            var worldY = Math.round(y * cellSize);

            if (debug.queryRects) {
              Main.Global.sb.emitProjectileGraphics(
                worldX,
                worldY,
                worldX,
                worldY,
                0, 'exported/square_white',
                0.01,
                (p, progress) -> cellSize,
                (p, progress) -> cellSize,
                (p, progress) -> 0.2
              );
            }


            var items = Grid.getItemsInRect(dynamicWorldRef, worldX, worldY, worldCellSize, worldCellSize);
            var staticWorld = Main.Global.mapRef;
            var obstacles = Grid.getItemsInRect(
              staticWorld, worldX, worldY, beamThickness + 16, beamThickness + 16
            );

            var checkCollisions = (items: Map<String, String>) -> {
              // trace(items);
              for (entityId in items) {
                var item = Entity.ALL_BY_ID[entityId];

                if (item.type == 'PLAYER') {
                  return false;
                }

                var colPt = new h2d.col.Point(item.x, item.y);
                var distFromStart = Utils.distance(x1, y1, colPt.x, colPt.y);

                // TODO add support for more accurate intersection point for line -> rectangle
                // We can figure out the edge that the beam touches and then find the intersection
                // point at the rectangle edge and the beam's center line.
                var isIntersecting = distFromStart <= maxLength
                  && centerLine.distance(colPt) <= item.radius + (beamThickness / 2);

                if (isIntersecting) {
                  // intersection point
                  var p = centerLine.project(colPt);

                  var laserHitCdKey = 'kamehamehaHit';
                  if (item.type == 'ENEMY' && !item.cds.has(laserHitCdKey)) {
                    item.cds.set(laserHitCdKey, 0.3);
                    item.damageTaken += 1;
                  }

                  adjustedEndPt = p;

                  if (debug.endPos) {
                    Main.Global.sb.emitProjectileGraphics(
                      x1,
                      y1,
                      x1,
                      y1,
                      0, 'exported/square_white',
                      0.01,
                      (p, progress) -> 10,
                      (p, progress) -> 10
                    );

                    Main.Global.sb.emitProjectileGraphics(
                      p.x,
                      p.y,
                      p.x,
                      p.y,
                      0, 'exported/square_white',
                      0.01,
                      (p, progress) -> 10,
                      (p, progress) -> 10
                    );
                  };
                }

                return isIntersecting;
              }

              return false;
            }

            return !checkCollisions(obstacles) && !checkCollisions(items);
          }
        );

        renderBeam(startPt, adjustedEndPt);
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

    var size = Utils.irnd(1, 2);
    var radius = 7 + size * 10;
    var posRange = 100;
    var e = new Enemy({
      x: x + Utils.irnd(-posRange, posRange),
      y: y + Utils.irnd(-posRange, posRange),
      radius: radius,
      weight: 1.0,
      color: colors[size],
    }, size, target);
    // TODO add support for draw-order of elements based on position
    parent.addChildAt(e, -1);
  }
}

class Game extends h2d.Object {
  public var level = 1;
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

  public function lineOfSight(entity, x, y, i) {
    var cellSize = mapRef.cellSize;
    var debugLineOfSight = false;
    var mapRef = Main.Global.mapRef;
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

  public function new(
    s2d: h2d.Scene,
    oldGame: Game
  ) {
    super();

    Main.Global.rootScene = s2d;

    Asset.loadMap(
      'test',
      (mapData: GridRef) -> {
        var color = Game.Colors.black;
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
            wallGraphic.beginFill(color, 0.8);
            wallGraphic.drawRect(-radius, -radius, radius * 2, radius * 2);
            Main.Global.rootScene.addChildAt(wallEnt, -1);
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
    s2d.addChildAt(player, -1);
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
          startGridX, startGridY, targetGridX, targetGridY, lineOfSight, enemy
        );
      }

      a.update(dt);

      // TODO need a better way to determine what is a dynamic entity
      if (a.type != 'OBSTACLE' && a.type != 'PROJECTILE') {
        Grid.setItemRect(dynamicWorldRef, a.x, a.y, a.radius, a.radius, a.id);
      }
    }

    target.x = s2d.mouseX;
    target.y = s2d.mouseY;
  }
}
