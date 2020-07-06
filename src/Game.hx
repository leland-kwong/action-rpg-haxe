/**
  TODO: Add enemy destroyed animation (fade out or explode into pieces?)
**/

import h2d.Bitmap;
import Grid.GridRef;
import Fonts;
import Utils;
import Camera;
import ParticlePlayground;
import Collision;

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
  var ?color: Int;
  var ?sightRange: Int;
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
        var nextPos = x + Utils.clamp(dx, -max, max) * speed * dt;
        var direction = dx > 0 ? 1 : -1;
        var isTraversable = Lambda.count(
          Grid.getItemsInRect(
            Main.Global.traversableGrid,
            Math.floor(x + (radius * direction)),
            Math.floor(y),
            1,
            1
          )
        ) > 0;

        if (isTraversable) {
          x = nextPos;
        }
      }

      if (dy != 0) {
        var nextPos = y + Utils.clamp(dy, -max, max) * speed * dt;
        var direction = dy > 0 ? 1 : -1;
        var isTraversable = Lambda.count(
          Grid.getItemsInRect(
            Main.Global.traversableGrid,
            Math.floor(x),
            Math.floor(y + (radius * direction)),
            1,
            1
          )
        ) > 0;

        if (isTraversable) {
          y = nextPos;
        }
      }
    }
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
    lifeTime = 2.0;
    particleSystemRef = Main.Global.sb;
    particle = particleSystemRef
      .emitSprite(
        x1, y1, x2, y2, speed, bulletType, lifeTime
      );
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
      particleSystemRef.removeSprite(particle);
    }
  }
}

class Enemy extends Entity {
  static var healthBySize = [
    1 => 5,
    2 => 10,
    3 => 100,
  ];
  static var speedBySize = [
    1 => 180.0,
    2 => 120.0,
    3 => 80.0,
  ];
  static var attackRangeByType = [
    1 => 80,
    2 => 300,
    3 => 200,
  ];
  static var spriteSheet: h2d.Tile;
  static var spriteSheetData: Dynamic;

  var font: h2d.Font = Fonts.primary.get().clone();
  var damage = 0;
  public var follow: Entity;
  public var canSeeTarget = true;
  var spawnDuration: Float;
  var size: Int;
  var repelFilter= 'REPEL_NONE';
  var debugCenter = false;
  var idleAnim: core.Anim.AnimRef;
  var runAnim: core.Anim.AnimRef;
  var activeAnim: core.Anim.AnimRef;
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

    if (props.sightRange != null) {
      sightRange = props.sightRange;
    }

    cds = new Cooldown();
    follow = followTarget;
    this.size = size;

    cds.set('summoningSickness', 1.0);
    setScale(0);

    if (size == 1) {
      var idleFrames = [
        'enemy-1_animation/idle-0',
        'enemy-1_animation/idle-1',
        'enemy-1_animation/idle-2',
        'enemy-1_animation/idle-3',
        'enemy-1_animation/idle-4',
        'enemy-1_animation/idle-5',
        'enemy-1_animation/idle-6',
        'enemy-1_animation/idle-7',
        'enemy-1_animation/idle-8',
        'enemy-1_animation/idle-9',
      ];
      idleAnim = {
        frames: idleFrames,
        duration: 1,
        startTime: Main.Global.time,
      }
      runAnim = idleAnim;
    }

    if (size == 2) {
      var idleFrames = [
        'enemy-2_animation/idle-0',
        'enemy-2_animation/idle-1',
      ];

      idleAnim = {
        frames: idleFrames,
        duration: 0.05,
        startTime: Main.Global.time,
      }

      var runFrames = [
        'enemy-2_animation/move-0',
        'enemy-2_animation/move-1',
      ];

      runAnim = {
        frames: runFrames,
        duration: 0.05,
        startTime: Main.Global.time,
      }
    }

    if (size == 3) {
      idleAnim = {
        frames: [
        'intro_boss_animation/idle-0',
      ],
        duration: 1,
        startTime: Main.Global.time
      };

      runAnim = {
        frames: [
          'intro_boss_animation/walk-0',
          'intro_boss_animation/walk-1',
          'intro_boss_animation/walk-2',
          'intro_boss_animation/walk-3',
          'intro_boss_animation/walk-4',
          'intro_boss_animation/walk-5',
          'intro_boss_animation/walk-6',
          'intro_boss_animation/walk-7',
        ],
        duration: 1,
        startTime: Main.Global.time
      };
    }
  }

  public override function update(dt) {
    dx = 0.0;
    dy = 0.0;

    super.update(dt);
    cds.update(dt);

    var origX = x;
    var origY = y;

    var spawnProgress = Math.min(1, time / spawnDuration);
    var isFullySpawned = spawnProgress >= 1;
    if (!isFullySpawned) {
      setScale(spawnProgress);
    }
    if (isFullySpawned) {
      status = 'TARGETABLE';
      speed = speedBySize[size];
    }

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

      var maxDelta = 1;
      x += Utils.clamp(dx, -maxDelta, maxDelta) *
        speed * dt;
      y += Utils.clamp(dy, -maxDelta, maxDelta) *
        speed * dt;
    }

    // update animation
    {
      var hasMovedX = Math.abs(origX - x) >= 0.25;
      var hasMovedY = Math.abs(origY - y) >= 0.25;
      var currentAnim = activeAnim;

      if (runAnim != null && (hasMovedX || hasMovedY)) {
        activeAnim = runAnim;
      }
      // set idle animation
      else {
        activeAnim = idleAnim;
      }

      if (activeAnim != null) {
        var isNewAnim = currentAnim != activeAnim;
        if (isNewAnim) {
          activeAnim.startTime = Main.Global.time;
        }

        if (dx != 0) {
          facingDir = (dx > 0 ? -1 : 1);
        }
        var currentFrameName = core.Anim.getFrame(activeAnim, Main.Global.time);
        Main.Global.sb.emitSprite(
          x, y,
          x, y,
          0,
          currentFrameName,
          0.001,
          (p, progress) -> facingDir * Main.Global.pixelScale,
          null,
          null,
          (p, progress) -> {
            if (cds.has('hitFlash')) {
              var b: h2d.SpriteBatch.BatchElement = p.batchElement;
              b.r = 255;
              b.g = 255;
              b.b = 255;
              b.a = 1;
            }
          }
        );
      }
      
      if (debugCenter) {
        var rScale = (_, _) -> 20;
        Main.Global.sb.emitSprite(
            x, y + 1,
            x, y + 1,
            0,
            'ui/square_white',
            0.001,
            rScale,
            rScale);
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
          'ui/bullet_enemy_large',
          ['PLAYER', 'OBSTACLE']
        );
        Main.Global.rootScene.addChild(b);
      }
    }

    // damage render effect
    {
      var c = activeAnim;

      if (damageTaken > 0) {
        cds.set('hitFlash', 0.04);
        health -= damageTaken;
        damageTaken = 0;
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
  var runAnim: core.Anim.AnimRef;
  var idleAnim: core.Anim.AnimRef;
  var attackAnim: core.Anim.AnimRef;
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
    speed = 800.0;
    forceMultiplier = 3.0;

    rootScene = s2d;

    var runFrames = [
      'player_animation/run-0',
      'player_animation/run-1',
      'player_animation/run-2',
      'player_animation/run-3',
      'player_animation/run-4',
      'player_animation/run-5',
      'player_animation/run-6',
      'player_animation/run-7',
    ];

    // creates an animation for these tiles
    runAnim = {
      frames: runFrames,
      duration: 0.3,
      startTime: Main.Global.time
    };

    var idleFrames = [
      'player_animation/idle-0'
    ];

    idleAnim = {
      frames: idleFrames,
      duration: 1,
      startTime: Main.Global.time
    };

    var attackSpriteFrames = [
      'player_animation/attack-0',
      'player_animation/attack-1',
      'player_animation/attack-2',
      'player_animation/attack-3',
      'player_animation/attack-4',
      'player_animation/attack-4',
      'player_animation/attack-4',
      'player_animation/attack-4',
      'player_animation/attack-4',
      'player_animation/attack-4',
      'player_animation/attack-4',
      'player_animation/attack-4',
    ];
    attackAnim = {
      frames: attackSpriteFrames,
      duration: 0.3,
      startTime: Main.Global.time
    };

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

    var activeAnim: core.Anim.AnimRef;
    if (cds.has('recoveringFromAbility')) {
      activeAnim = attackAnim;
    }
    else {
      if (dx != 0 || dy != 0) {
        activeAnim = runAnim;
      } else {
        activeAnim = idleAnim;
      }
    }

    Main.Global.sb.emitSprite(
      x, y,
      x, y,
      0,
      core.Anim.getFrame(activeAnim, Main.Global.time),
      0.001,
      (_, _) ->  Main.Global.pixelScale * facingX,
      (_, _) -> Main.Global.pixelScale
    );

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
    var yCenterOffset = -7 * Main.Global.pixelScale;
    var startY = y + yCenterOffset;

    switch ability {
      case 0: {
        if (cds.has('primaryAbility')) {
          return;
        }
        var abilityCooldown = 1/10;
        cds.set('recoveringFromAbility', abilityCooldown);
        attackAnim.startTime = Main.Global.time;

        var angle = Math.atan2(y2 - startY, x2 - x);
        var x1 = x + Math.cos(angle) * 30;
        var y1 = startY + Math.sin(angle) * 30;
        var b = new Bullet(
          x1,
          y1,
					x2,
					y2,
          800.0,
          'ui/bullet_player_basic',
          ['ENEMY', 'OBSTACLE']
        );
        Main.Global.rootScene.addChild(b);
        cds.set('primaryAbility', abilityCooldown);
      }

      case 1: {
        if (cds.has('ability_2')) {
          return;
        }

        var abilityCooldown = 0.02;
        var pixelScale = Main.Global.pixelScale;
        var beamThickness = 60;
        var laserHeadSpriteData = Reflect.field(
          Main.Global.sb.pSystem.spriteSheetData,
          'ui/kamehameha_head'
        );
        var laserTailSpriteData = Reflect.field(
          Main.Global.sb.pSystem.spriteSheetData,
          'ui/kamehameha_tail'
        );
        var laserHeadWidth = laserHeadSpriteData.frame.w * pixelScale;
        var laserTailWidth = laserTailSpriteData.frame.w * pixelScale;
        var maxLength = 700;
        cds.set('recoveringFromAbility', abilityCooldown);
        var launchOffset = 30;
        var angle = Math.atan2(y2 - startY, x2 - x);
        var vx = Math.cos(angle);
        var vy = Math.sin(angle);
        // initial launch point
        var x1 = x + vx * launchOffset;
        var y1 = startY + vy * launchOffset;
        var laserTailX1 = x1 + vx * maxLength;
        var laserTailY1 = y1 + vy * maxLength;
        var yScaleRand = Utils.irnd(0, 1) * 0.5;
        var beamOpacity = (p, progress) -> 1;

        var renderBeam = (startPt, endPt) -> {
          var spriteLifetime = 1/60;
          // laser head
          Main.Global.sb.emitSprite(
            startPt.x, startPt.y,
            endPt.x, endPt.y,
            0, 'ui/kamehameha_head',
            spriteLifetime ,
            null,
            (p, progress) -> pixelScale + yScaleRand,
            beamOpacity
          );

          var lcx = startPt.x + (vx * laserHeadWidth);
          var lcy = startPt.y + (vy * laserHeadWidth);
          {
            var beamLength = (p, progress) -> Utils.distance(lcx, lcy, endPt.x, endPt.y);
            var beamScaleY = (p, progress) -> pixelScale + yScaleRand;

            // laser center
            Main.Global.sb.emitSprite(
              lcx, lcy,
              endPt.x, endPt.y,
              0, 'ui/kamehameha_center_width_1',
              spriteLifetime,
              beamLength,
              beamScaleY,
              beamOpacity
            );
          }

          // laser tail
          Main.Global.sb.emitSprite(
            endPt.x, endPt.y,
            endPt.x + vx, endPt.y + vy,
            0, 'ui/kamehameha_tail',
            spriteLifetime,
            (p, progress) -> pixelScale + Utils.irnd(0, 1),
            (p, progress) -> pixelScale + yScaleRand,
            beamOpacity
          );
        }

        var dynamicWorldGrid = Main.Global.dynamicWorldGrid;
        var worldCellSize = dynamicWorldGrid.cellSize;
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
          Main.Global.sb.emitSprite(
            laserTailX1, laserTailY1,
            laserTailX1, laserTailY1,
            0, 'ui/square_white',
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
              Main.Global.sb.emitSprite(
                worldX,
                worldY,
                worldX,
                worldY,
                0, 'ui/square_white',
                0.01,
                (p, progress) -> cellSize,
                (p, progress) -> cellSize,
                (p, progress) -> 0.8
              );
            }

            var items = Grid.getItemsInRect(dynamicWorldGrid, worldX, worldY, worldCellSize, worldCellSize);
            var staticWorld = Main.Global.obstacleGrid;
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

                var colCircle = new h2d.col.Circle(item.x, item.y, item.radius);
                // var colPt = new h2d.col.Point(item.x, item.y);
                var intersectionPoint = Collision.beamCircleIntersectTest(
                    startPt, 
                    endPt,
                    colCircle,
                    beamThickness);
                var isIntersecting = intersectionPoint != endPt;
                Main.Global.sb.emitSprite(
                  intersectionPoint.x, intersectionPoint.y,
                  intersectionPoint.x, intersectionPoint.y,
                  0, 'ui/square_white',
                  0.01,
                  (p, progress) -> 10,
                  (p, progress) -> 10
                );

                // var distFromStart = Utils.distance(x1, y1, colPt.x, colPt.y);
                // var endPtCircleIntersects = Utils.distance(colPt.x, colPt.y, worldX, worldY)
                //   <= item.radius;

                // // TODO add support for more accurate intersection point for line -> rectangle
                // // We can figure out the edge that the beam touches and then find the intersection
                // // point at the rectangle edge and the beam's center line.
                // var isIntersecting = endPtCircleIntersects || (
                //   distFromStart <= maxLength
                //     && centerLine.distance(colPt) <= item.radius + (beamThickness / 2)
                // );

                if (isIntersecting) {
                  var circleCol = new h2d.col.Circle(item.x, item.y, item.radius);
                  var trueIntersectionPts = circleCol.lineIntersect(centerLine.p1, centerLine.p2);
                  // intersection point
                  var p = intersectionPoint;

                  var laserHitCdKey = 'kamehamehaHit';
                  if (item.type == 'ENEMY' && !item.cds.has(laserHitCdKey)) {
                    item.cds.set(laserHitCdKey, 0.3);
                    item.damageTaken += 1;
                  }

                  adjustedEndPt = p;

                  if (debug.endPos) {
                    Main.Global.sb.emitSprite(
                      x1,
                      y1,
                      x1,
                      y1,
                      0, 'ui/square_white',
                      0.01,
                      (p, progress) -> 10,
                      (p, progress) -> 10
                    );

                    Main.Global.sb.emitSprite(
                      p.x,
                      p.y,
                      p.x,
                      p.y,
                      0, 'ui/square_white',
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
    parent.addChildAt(e, 0);
  }
}

typedef TiledMapData = { 
  layers:Array<{ data:Array<Int>}>, 
  tilewidth:Int, 
  tileheight:Int, 
  width:Int, 
  height:Int 
};

typedef MapDataRef = {
  var data: TiledMapData;
  var layersByName: Map<String, Dynamic>;
}

typedef TiledObject = {
  var id: Int;
  var x: Int;
  var y: Int;
  var width: Int;
  var height: Int;
}

class MapData {
  static var cache: MapDataRef;
  static var previousTiledRes: hxd.res.Resource;

  static public function create(tiledRes: hxd.res.Resource) {
    if (previousTiledRes == tiledRes) {
      return cache;
    }

    // parse Tiled json file
    var mapData:TiledMapData = haxe.Json.parse(hxd.Res.level_intro_json.entry.getText());
    var layersByName: Map<String, Dynamic> = new Map();
    var mapLayers: Array<Dynamic> = mapData.layers;

    for (l in mapLayers) {
      layersByName.set(l.name, l);
    }

    return {
      data: mapData,
      layersByName: layersByName
    };
  }
}

class Game extends h2d.Object {
  public var level = 1;
  var player: Player;
  var mousePointer: h2d.Object;
  var mousePointerSprite: h2d.Graphics;
  var playerInfo: h2d.Text;
  var mapRef: GridRef;
  var dynamicWorldGrid: GridRef = Grid.create(64);
  var TARGET_RADIUS = 20.0;
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

    mousePointer.remove();
    playerInfo.remove();
  }

  override function onRemove() {
    cleanupLevel();
    cleanupDisposedEntities();
  }

  public function newLevel(s2d: h2d.Scene) {
    level += 1;

    // TODO re-enable when spawn positions are setup
    enemySpawner = new EnemySpawner(
      800 * Main.Global.pixelScale,
      900 * Main.Global.pixelScale,
      calcNumEnemies(level),
      s2d,
      player
    );


    // intro_boss
    {
      var parsedTiledMap = MapData.create(hxd.Res.level_intro_json);
      var layersByName = parsedTiledMap.layersByName;
      var mapObjects: Array<Dynamic> = layersByName.get('objects').objects;
      var miniBossPos: Dynamic = Lambda.find(mapObjects, (item) -> item.name == 'mini_boss_position');
      var size = 3;

      var e = new Enemy({
        x: miniBossPos.x * Main.Global.pixelScale,
        y: miniBossPos.y * Main.Global.pixelScale,
        radius: 30 * Main.Global.pixelScale,
        sightRange: 600,
        weight: 1.0,
        color: Game.Colors.yellow,
      }, size, player);
      Main.Global.rootScene.addChildAt(e, 0);
    }
  }

  public function lineOfSight(entity, x, y, i) {
    var cellSize = mapRef.cellSize;
    var mapRef = Main.Global.obstacleGrid;
    var isClearPath = Grid.isEmptyCell(mapRef, x, y);
    var isInSightRange = i * cellSize <= entity.sightRange;

    if (!isClearPath || !isInSightRange) {
      entity.canSeeTarget = false;
      return false;
    }

    return isClearPath;
  }

  public function new(
    s2d: h2d.Scene,
    oldGame: Game
  ) {
    super();

    Main.Global.traversableGrid = Grid.create(16 * Main.Global.pixelScale);

    // load map background
    {
      var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
      var spriteSheetData = Utils.loadJsonFile(hxd.Res.sprite_sheet_json).frames;
      var bgData = Reflect.field(spriteSheetData, 'ui/level_intro');
      var tile = spriteSheet.sub(
        bgData.frame.x,
        bgData.frame.y,
        bgData.frame.w,
        bgData.frame.h
      );
      var bmp = new h2d.Bitmap(tile, s2d);
      bmp.setScale(Main.Global.pixelScale);
    }

    var parsedTiledMap = MapData.create(hxd.Res.level_intro_json);
    var layersByName = parsedTiledMap.layersByName;
    var mapObjects: Array<Dynamic> = layersByName.get('objects').objects;
    // var playerStartPos: Dynamic = Lambda.find(mapObjects, (item) -> item.name == 'player_start');

    var miniBossPos: Dynamic = Lambda.find(mapObjects, (item) -> item.name == 'mini_boss_position');
    var playerStartPos = { x: miniBossPos.x - 35 * Main.Global.pixelScale, y: miniBossPos.y };

    Main.Global.rootScene = s2d;

    // setup traversible grid
    {
      var traversableRects: Array<Dynamic> = layersByName.get('traversable').objects;
      var pixelScale = Main.Global.pixelScale;
      var updateTraversableGrid = (item: TiledObject) -> {
        // trace(item);
        Grid.setItemRect(
          Main.Global.traversableGrid,
          (item.x + item.width / 2) * pixelScale,
          (item.y + item.height / 2) * pixelScale,
          item.width * pixelScale,
          item.height * pixelScale,
          Std.string(item.id)
        );
        return true;
      }
      Lambda.foreach(traversableRects, updateTraversableGrid);

      var debugTraversalGrid = false;
      if (debugTraversalGrid) {
        // debug traversable positions
        var traversableGridItems = Main.Global.traversableGrid.itemCache;
        var g = new h2d.Graphics(Main.Global.debugScene);
        g.beginFill(Game.Colors.yellow, 0.3);
        var cellSize = Main.Global.traversableGrid.cellSize;
        trace('cellSize', cellSize);
        for (key => item in traversableGridItems) {
          trace(key, item);
          var xMin = item[0] * cellSize;
          var xMax = item[1] * cellSize;
          var yMin = item[2] * cellSize;
          var yMax = item[3] * cellSize;
          var width = xMax - xMin;
          var height = yMax - yMin;

          g.drawRect(xMin, yMin, width, height);
        }
      }
    }

    // setup environment obstacle colliders
    {
      mapRef = Grid.create(64);
    }

    s2d.addChild(this);
    if (oldGame != null) {
      oldGame.cleanupLevel();
    }
    player = new Player(
      playerStartPos.x * Main.Global.pixelScale,
      playerStartPos.y * Main.Global.pixelScale - 6,
      s2d
    );
    s2d.addChildAt(player, 0);
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
    mousePointer = new h2d.Object(this);
    mousePointerSprite = new h2d.Graphics(mousePointer);
    mousePointerSprite.beginFill(0xffda3d, 0.3);
    mousePointerSprite.drawCircle(0, 0, TARGET_RADIUS);
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
        Grid.removeItem(dynamicWorldGrid, a.id);
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

    // sort dynamic objects in main world by their y position
    Main.Global.rootScene.children.sort((a, b) -> {
      if (a.y > b.y) {
        return 1;
      }

      if (a.y < b.y) {
        return -1;
      }

      return 0;
    });

    Main.Global.obstacleGrid = mapRef;
    Main.Global.dynamicWorldGrid = dynamicWorldGrid;

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
        var height = a.radius * 2 + nRange;
        var width = height;
        var dynamicNeighbors = Grid.getItemsInRect(
          dynamicWorldGrid, a.x, a.y, width, height
        );
        var obstacleNeighbors = Grid.getItemsInRect(
          mapRef, a.x, a.y, width, height
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
        Grid.setItemRect(
          dynamicWorldGrid,
          a.x,
          a.y,
          a.radius * 2,
          a.radius * 2,
          a.id
        );
      }
    }

    mousePointer.x = s2d.mouseX;
    mousePointer.y = s2d.mouseY;

    // display hovered object
    {
      var mouseNeighbors = Grid.getItemsInRect(
        Main.Global.dynamicWorldGrid,
        mousePointer.x,
        mousePointer.y,
        1,
        1
      );

      for (item in mouseNeighbors) {
        // trace(item);
      }
    }
  }
}
