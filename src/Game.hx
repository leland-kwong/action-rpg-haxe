using core.Types;

import h2d.Bitmap;
import Grid.GridRef;
import Fonts;
import Utils;
import Camera;
import SpriteBatchSystem;
import Collision;
import Entity;

using Lambda;

class SoundFx {
  public static var globalCds = new Cooldown();

  public static function bulletBasic(cooldown = 0.1) {
    if (Cooldown.has(globalCds, 'bulletBasic')) {
      return;
    }
    Cooldown.set(globalCds, 'bulletBasic', cooldown);

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

class Projectile extends Entity {
  var damage = 1;
  var lifeTime = 5.0;
  var collidedWith: Entity;
  var cFilter: EntityFilter;

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
    var dxNormalized = magnitude == 0 
      ? _dx : _dx / magnitude;
    var dyNormalized = magnitude == 0 
      ? _dy : _dy / magnitude;
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
      final a = Entity.getById(id);
      if (cFilter(a)) {
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
  static var onHitFrames = [
    'projectile_hit_animation/burst-0',
    'projectile_hit_animation/burst-1',
    'projectile_hit_animation/burst-2', 
    'projectile_hit_animation/burst-3', 
    'projectile_hit_animation/burst-4', 
    'projectile_hit_animation/burst-5', 
    'projectile_hit_animation/burst-6', 
    'projectile_hit_animation/burst-7', 
  ];
  var launchSoundPlayed = false;
  var spriteKey: String;

  public function new(
    x1, y1, x2, y2, speed, 
    _spriteKey, collisionFilter
  ) {
    super(x1, y1, x2, y2, speed, 8, collisionFilter);
    lifeTime = 2.0;
    spriteKey = _spriteKey;
  }

  public override function onRemove() {
    core.Anim.AnimEffect.add({
      frames: onHitFrames,
      startTime: Main.Global.time,
      duration: 0.15,
      x: x,
      y: y
    }); 
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
    }
  }

  public override function render(time: Float) {
    final angle = Math.atan2(
        y + dy - y,
        x + dx - x);
    Main.Global.sb.emitSprite(
        x, y, spriteKey, angle, null, 1);
  }
}


typedef EntityFilter = (ent: Entity) -> Bool;

class Ai extends Entity {
  static var healthBySize = [
    1 => 5,
    2 => 10,
    3 => 30,
    4 => 50,
  ];
  static var speedBySize = [
    1 => 90.0,
    2 => 60.0,
    3 => 40.0,
    4 => 100.0,
  ];
  static var attackRangeByType = [
    1 => 30,
    2 => 120,
    3 => 80,
    4 => 13,
  ];
  static final defaultAttackTargetFilterFn: EntityFilter = 
    (ent) -> {
      return ent.type == 'PLAYER' 
        || ent.type == 'OBSTACLE';
    };
  final attackTypeBySpecies = [
    1 => 'attack_bullet',
    2 => 'attack_bullet',
    3 => 'attack_bullet',
    4 => 'attack_self_detonate',
  ];
  static var spriteSheet: h2d.Tile;
  static var spriteSheetData: Dynamic;

  var font: h2d.Font = Fonts.primary.get().clone();
  var damage = 0;
  public var follow: Entity;
  public var canSeeTarget = true;
  var spawnDuration: Float = 0.1;
  var size: Int;
  var debugCenter = false;
  var idleAnim: core.Anim.AnimRef;
  var runAnim: core.Anim.AnimRef;
  var activeAnim: core.Anim.AnimRef;
  var facingDir = 1;
  public var sightRange = 200;
  public var attackTarget: Entity;
  var findTargetFn: (self: Entity) -> Entity;
  var attackTargetFilterFn: EntityFilter = 
    defaultAttackTargetFilterFn;

  public function new(
      props, size, 
      findTargetFn, ?attackTargetFilterFn) {
    super(props);
    neighborCheckInterval = 10;
    traversableGrid = Main.Global.traversableGrid;

    cds = new Cooldown();

    if (spriteSheet == null) {
      spriteSheet = hxd.Res.sprite_sheet_png.toTile();
      spriteSheetData = Utils.loadJsonFile(
          hxd.Res.sprite_sheet_json).frames;
    }

    type = 'ENEMY';
    status = 'UNTARGETABLE';
    speed = 0.0;
    health = healthBySize[size];
    stats = PlayerStats.create({
      maxHealth: health,
      currentHealth: health,
      maxEnergy: 0,
      currentEnergy: 0,
      energyRegeneration: 0
    });
    avoidOthers = true;
    this.findTargetFn = findTargetFn;
    if (attackTargetFilterFn != null) {
      this.attackTargetFilterFn = attackTargetFilterFn;
    }

    if (props.sightRange != null) {
      sightRange = props.sightRange;
    }

    cds = new Cooldown();
    this.size = size;

    Cooldown.set(cds, 'recentlySummoned', spawnDuration);

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

    if (size == 4) {
      idleAnim = {
        frames: [
        'spider_bot_animation/idle-0',
      ],
        duration: 1,
        startTime: Main.Global.time
      };

      runAnim = {
        frames: [
          'spider_bot_animation/walk_run-0',
          'spider_bot_animation/walk_run-1',
          'spider_bot_animation/walk_run-2',
          'spider_bot_animation/walk_run-3',
          'spider_bot_animation/walk_run-4',
        ],
        duration: 0.2,
        startTime: Main.Global.time
      };
    }
  }

  public override function update(dt) {
    dx = 0.0;
    dy = 0.0;

    Cooldown.update(cds, dt);

    follow = findTargetFn(this);
    var origX = x;
    var origY = y;

    if (!Cooldown.has(cds, 'recentlySummoned')) {
      status = 'TARGETABLE';
      speed = speedBySize[size];
    }

    if (follow != null && !Cooldown.has(cds, 'attack')) {
      // distance to keep from destination
      var threshold = follow.radius + 5;
      var attackRange = attackRangeByType[size];
      var dFromTarget = Utils.distance(x, y, follow.x, follow.y);
      // exponential drop-off as agent approaches destination
      var speedAdjust = Math.max(
          0, Math.min(
            1, Math.pow(
              (dFromTarget - threshold) / threshold, 2)));
      if (canSeeTarget && dFromTarget > threshold) {
        var aToTarget = Math.atan2(follow.y - y, follow.x - x);
        dx += Math.cos(aToTarget) * speedAdjust;
        dy += Math.sin(aToTarget) * speedAdjust;
      }

      if (avoidOthers) {
        // make entities avoid each other by repulsion
        for (oid in neighbors) {
          var o = Entity.getById(oid);
          var pt = this;
          var ept = o;
          var d = Utils.distance(pt.x, pt.y, ept.x, ept.y);

          if (o.forceMultiplier > 0) {
            var separation = Math.sqrt(speed / 4);
            var min = pt.radius + ept.radius + separation;
            var isColliding = d < min;
            if (isColliding) {
              var conflict = min - d;
              var adjustedConflict = Math.min(
                  conflict, conflict * 15 / speed);
              var a = Math.atan2(ept.y - pt.y, ept.x - pt.x);
              var w = pt.weight / (pt.weight + ept.weight);
              // immobile entities have a stronger influence (obstacles such as walls, etc...)
              var multiplier = ept.forceMultiplier;
              var avoidX = Math.cos(a) * adjustedConflict 
                * w * multiplier;
              var avoidY = Math.sin(a) * adjustedConflict 
                * w * multiplier;

              dx -= avoidX;
              dy -= avoidY;
            }
          }
        }
      }

      if (canSeeTarget && attackTarget == null) {
        var isInAttackRange = dFromTarget <= 
          attackRange + follow.radius;
        if (isInAttackRange) {
          attackTarget = follow;
        }
      }
    }

    // update animation
    {
      var currentAnim = activeAnim;

      activeAnim = {
        var isMovingX = Math.abs(dx) >= 0.05;
        var isMovingY = Math.abs(dy) >= 0.05;

        if ((isMovingX || isMovingY)) {
          runAnim;
        } else {
          idleAnim;
        }
      }

      if (activeAnim != null) {
        var isNewAnim = currentAnim != activeAnim;
        if (isNewAnim) {
          activeAnim.startTime = Main.Global.time;
        }

        if (dx != 0) {
          facingDir = (dx > 0 ? -1 : 1);
        }
      }
      
      if (debugCenter) {
        var spriteEffect = (p) -> {
          final scale = radius * 2;
          final b: h2d.SpriteBatch.BatchElement = p.batchElement;

          b.alpha = 0.2;
          b.scaleX = scale;
          b.scaleY = scale;
        }
        // TODO: should move this to a render method
        Main.Global.sb.emitSprite(
            x, y,
            'ui/square_white',
            null,
            spriteEffect);
      }
    }

    // trigger attack
    if (!Cooldown.has(cds, 'recentlySummoned') && attackTarget != null) {
      final isValidTarget = attackTargetFilterFn(attackTarget);
      if (!Cooldown.has(cds, 'attack') && isValidTarget) {
        final attackType = attackTypeBySpecies[size];

        switch (attackType) {
          case 'attack_bullet': {
            var attackCooldown = 1.0;
            Cooldown.set(cds, 'attack', attackCooldown);

            var x2 = follow.x;
            var y2 = follow.y;
            var launchOffset = radius;
            var angle = Math.atan2(y2 - y, x2 - x);
            var b = new Bullet(
                x + Math.cos(angle) * launchOffset,
                y + Math.sin(angle) * launchOffset,
                x2,
                y2,
                100.0,
                'ui/bullet_enemy_large',
                attackTargetFilterFn);
            Main.Global.rootScene.addChild(b);
          }

          case 'attack_self_detonate': {
            final startTime = Main.Global.time;
            final duration = 0.4;
            core.Anim.AnimEffect.add({
              x: x, 
              y: y,
              z: 2,
              frames: [
                'explosion_animation/default-0'
              ],
              startTime: startTime,
              duration: duration,
              effectCallback: (p) -> {
                final b: h2d.SpriteBatch.BatchElement 
                  = p.batchElement;
                final aliveTime = Main.Global.time 
                  - startTime;
                final progress = Easing
                  .easeInCirc(aliveTime / duration);
                
                final scale = 2;
                b.scale = scale - (scale * progress); 
                b.alpha = 0.5;
                b.g = 1 - progress * 0.2;
                b.b = 1 - progress * 0.7;
              }
            });
            health = 0;
            attackTarget.damageTaken += 2;
            final aoeSize = 30; // diameter
            // deal damage to other nearby enemies
            final nearbyEntities = Grid.getItemsInRect(
                Main.Global.dynamicWorldGrid,
                x, y, aoeSize, aoeSize);
            for (entityId in nearbyEntities) {
              final entityRef = Entity.getById(entityId);

              if (entityRef != attackTarget 
                  && attackTargetFilterFn(entityRef)) {
                entityRef.damageTaken += 2;
              }
            }
          }

          default: {
#if !production
            throw 'invalid attack type `${attackType}`';
#end
          }
        }
      }
    }

    // damage render effect
    {
      var c = activeAnim;

      if (damageTaken > 0) {
        Cooldown.set(cds, 'hitFlash', 0.02);
        health -= damageTaken;
        damageTaken = 0;
      }
    }

    attackTarget = null;

    if (isDone()) {
      // trigger death animation
      final startTime = Main.Global.time;
      final frames = [
        'destroy_animation/default-0',
        'destroy_animation/default-1',
        'destroy_animation/default-2',
        'destroy_animation/default-3',
        'destroy_animation/default-4',
        'destroy_animation/default-5',
        'destroy_animation/default-6',
        'destroy_animation/default-7',
        'destroy_animation/default-8',
        'destroy_animation/default-9',
      ];

      for (_ in 0...Utils.irnd(3, 4)) {
        final duration = Utils.rnd(0.3, 0.7);
        final z = Utils.irnd(0, 1);
        final dx = Utils.irnd(-6, 6, true);
        final dy = Utils.irnd(-6, 6, true);
        core.Anim.AnimEffect.add({
          x: x + dx,
          y: y + dy,
          z: z,
          dx: Utils.rnd(1, 2) * dx,
          dy: Utils.rnd(1, 2) * dy,
          startTime: startTime,
          duration: duration,
          frames: frames });
      }

      final shouldDropLoot = type == 'ENEMY';
      if (shouldDropLoot) {
        final lootRef = new Entity({
          x: x, 
          y: y,
          radius: 11,
        }); 
        lootRef.type = 'LOOT';
        lootRef.renderFn = (ref, time: Float) -> {
          Main.Global.sb.emitSprite(
              ref.x - ref.radius,
              ref.y + ref.radius - 2,
              'ui/square_white',
              null,
              (p) -> {
                p.sortOrder = y - 1;
                p.batchElement.scaleX = ref.radius * 2;
                p.batchElement.r = 0;
                p.batchElement.g = 0;
                p.batchElement.b = 0.2;
                p.batchElement.a = 0.2;
                p.batchElement.scaleY = ref.radius * 0.5;
              });

          final lootRenderFn = (p: SpriteRef) -> {
            p.sortOrder = y - 1;

            if (Main.Global.hoveredEntity.id == 
                ref.id) {
              final hoverStart = Main.Global
                .hoveredEntity.hoverStart;
              p.batchElement.y = ref.y - 
                Math.abs(
                    Math.sin(time - hoverStart)) * 2;
              p.batchElement.b = 0;
              p.batchElement.r = 0;
              p.batchElement.g = 1;
            }
          };
          Main.Global.sb.emitSprite(
              ref.x,
              ref.y,
              'ui/loot__ability_spider_bot',
              null,
              lootRenderFn);
        };
      }
    }

    super.update(dt);
  }

  public override function render(time: Float) {
    final currentFrameName = core.Anim.getFrame(
        activeAnim, time);

    Main.Global.sb.emitSprite(
        x, y,
        currentFrameName,
        null,
        (p) -> {
          final b: h2d.SpriteBatch.BatchElement = 
            p.batchElement;

          if (Cooldown.has(cds, 'hitFlash')) {
            b.r = 2.75;
            b.g = 2.75;
            b.b = 2.5;
          }

          b.scaleX = facingDir * 1;
        });
  }
}

class Player extends Entity {
  var rootScene: h2d.Scene;
  var runAnim: core.Anim.AnimRef;
  var idleAnim: core.Anim.AnimRef;
  var attackAnim: core.Anim.AnimRef;
  var runAnimFrames: Array<h2d.Tile>;
  var idleAnimFrames: Array<h2d.Tile>;
  var abilityEvents: Array<{
    type: String,
    startPoint: h2d.col.Point,
    endPoint: h2d.col.Point
  }>;
  var facingX = 1;

  public function new(x, y, s2d: h2d.Scene) {
    super({
      x: x,
      y: y,
      radius: 6,
      weight: 1.0,
      id: 'PLAYER'
    });
    cds = new Cooldown();
    type = 'PLAYER';
    health = 1000;
    speed = 200.0;
    forceMultiplier = 5.0;
    traversableGrid = Main.Global.traversableGrid;
    obstacleGrid = Main.Global.obstacleGrid;

    rootScene = s2d;
    Main.Global.playerStats = PlayerStats.create({
      maxHealth: 100,
      maxEnergy: 100,
      currentHealth: 100.0,
      currentEnergy: 100.0,
      energyRegeneration: 10, // per second
    });

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
  }

  function movePlayer() {
    var Key = hxd.Key;

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
    var dxNormalized = magnitude == 0 
      ? dx : (dx / magnitude);
    var dyNormalized = magnitude == 0 
      ? dy : (dy / magnitude);

    dx = dxNormalized;
    dy = dyNormalized;
  }

  public override function update(dt) {
    super.update(dt);
    Cooldown.update(cds, dt);
    abilityEvents = [];

    dx = 0;
    dy = 0;

    // collision avoidance
    if (neighbors != null) {
      for (entityId in neighbors) {
        final entity = Entity.getById(entityId);

        if (entity.type == 'FRIENDLY_AI') {
          continue;
        }

        final r2 = entity.avoidanceRadius;
        final a = Math.atan2(y - entity.y, x - entity.x);
        final d = Utils.distance(entity.x, entity.y, x, y);
        final min = radius + r2;
        final isColliding = d < min;

        if (isColliding) {
          final conflict = (min - d);

          x += Math.cos(a) * conflict; 
          y += Math.sin(a) * conflict; 
        }
      }
    }

    useAbility();

    if (!Cooldown.has(cds, 'recoveringFromAbility')) {
      movePlayer();
    }

    {
      if (damageTaken > 0) {
        PlayerStats.addEvent(
            Main.Global.playerStats, 
            { type: 'DAMAGE_RECEIVED', 
              value: damageTaken });
        damageTaken = 0;
      }
    }
  }

  public function useAbility() {

    if (Cooldown.has(cds, 'recoveringFromAbility')) {
      return;
    }
    
    final abilityIdByMouseBtn = [
      -1 => -1,
      0 => 0,
      1 => 1,
      2 => -1,
      3 => 2,
      4 => 3
    ];
    final abilityId = abilityIdByMouseBtn[
      Main.Global.worldMouse.buttonDown];
    final x2 = Main.Global.rootScene.mouseX;
    final y2 = Main.Global.rootScene.mouseY;
    final actionDx = Math.cos(Math.atan2(y2 - y, x2 - x));

    if (actionDx != 0) {
      facingX = actionDx > 0 ? 1 : -1;
    }

    var yCenterOffset = -8;
    var startY = y + yCenterOffset;
    var launchOffset = 12;

    switch abilityId {
      case 0: {
        var energyCost = 2;
        var hasEnoughEnergy = energyCost 
          <= Main.Global.playerStats.currentEnergy;
        var isUnavailable = Cooldown.has(cds, 'primaryAbility') 
          || !hasEnoughEnergy;

        if (isUnavailable) {
          return;
        }

        var abilityCooldown = 1/10;
        Cooldown.set(cds, 'recoveringFromAbility', abilityCooldown);
        attackAnim.startTime = Main.Global.time;

        var angle = Math.atan2(y2 - startY, x2 - x);
        var x1 = x + Math.cos(angle) * launchOffset;
        var y1 = startY + Math.sin(angle) * launchOffset;
        var b = new Bullet(
          x1,
          y1,
					x2,
					y2,
          250.0,
          'ui/bullet_player_basic',
          (ent) -> (
            ent.type == 'ENEMY' || 
            ent.type == 'OBSTACLE')
        );
        Main.Global.rootScene.addChild(b);
        Cooldown.set(cds, 'primaryAbility', abilityCooldown);

        PlayerStats.addEvent(
            Main.Global.playerStats, 
            { type: 'ENERGY_SPEND',
              value: energyCost });
      }

      case 1: {
        final tempState = Main.Global.tempState;
        final tickKey = 'kamehamehaChanneling';
        // handle beam channel ticks
        {
          final baseTickAmount = 0.3;
          final tickRate = .01;
          if (Cooldown.has(cds, tickKey)) {
            final curTick = Utils.withDefault(
                tempState.get(tickKey), 0);
            tempState.set(tickKey, Math.min(1, curTick + tickRate));
          } else {
            tempState.set(tickKey, baseTickAmount);
          }
          Main.Global.logData.kamehamehaChannelTick = 
            tempState.get(tickKey);
          Cooldown.set(cds, tickKey, 0.05);
        }

        final additionalLength = 40 * Math.max(1, tempState.get(tickKey) * 2);
        final maxLength = 60 + additionalLength; 
        Main.Global.logData.laserMaxLength = maxLength;
        final abilityCooldown = 0.0001;
        final laserCenterSpriteData = Reflect.field(
            Main.Global.sb.batchManager.spriteSheetData,
            'ui/kamehameha_center_width_1'
            );
        final beamThickness = 
          laserCenterSpriteData.frame.h;
        final laserTailSpriteData = Reflect.field(
          Main.Global.sb.batchManager.spriteSheetData,
          'ui/kamehameha_tail');
        Cooldown.set(cds, 'recoveringFromAbility', abilityCooldown);
        final angle = Math.atan2(y2 - startY, x2 - x);
        final vx = Math.cos(angle);
        final vy = Math.sin(angle);
        // initial launch point
        final x1 = x + vx * launchOffset;
        final y1 = startY + vy * launchOffset;
        final laserTailX1 = x1 + vx * maxLength;
        final laserTailY1 = y1 + vy * maxLength;

        var dynamicWorldGrid = Main.Global.dynamicWorldGrid;
        var worldCellSize = dynamicWorldGrid.cellSize;
        var cellSize = 3;
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
          // TODO: should be moved to a render method
          Main.Global.sb.emitSprite(
            laserTailX1, laserTailY1,
            'ui/square_white',
            null,
            (p) -> {
              final scale = 10;
              final b: h2d.SpriteBatch.BatchElement = p.batchElement;

              b.scaleX = scale;
            }
          );
        }

        var adjustedEndPt = endPt;

        Utils.bresenhamLine(
            startGridX, startGridY, targetGridX, 
            targetGridY, (ctx, x, y, i) -> {

            var worldX = Math.round(x * cellSize);
            var worldY = Math.round(y * cellSize);

            if (debug.queryRects) {
              // TODO: should be moved to a render method
              Main.Global.sb.emitSprite(
                worldX,
                worldY,
                'ui/square_white',
                null,
                (p) -> {
                  final scale = cellSize;
                  final b: h2d.SpriteBatch.BatchElement = p.batchElement;

                  b.scaleX = scale;
                  b.scaleY = scale; 
                }
              );
            }

            var items = Grid.getItemsInRect(
                dynamicWorldGrid, worldX, worldY, 
                worldCellSize, worldCellSize);
            var staticWorld = Main.Global.obstacleGrid;
            var obsWorldCellSize = beamThickness + 16;
            var obstacles = Grid.getItemsInRect(
              staticWorld, worldX, worldY, 
              obsWorldCellSize, obsWorldCellSize);

            var checkCollisions = (items: Map<String, String>) -> {
              for (entityId in items) {
                var item = Entity.getById(entityId);

                if (item.type == 'PLAYER' 
                    || item.type == 'FRIENDLY_AI') {
                  return false;
                }

                var colCircle = new h2d.col.Circle(
                    item.x, item.y, item.radius);
                // var colPt = new h2d.col.Point(item.x, item.y);
                var intersectionPoint = Collision
                  .beamCircleIntersectTest(
                      startPt, 
                      endPt,
                      colCircle,
                      beamThickness);
                var isIntersecting = intersectionPoint != endPt;

                // TODO add support for more accurate intersection point for line -> rectangle
                // We can figure out the edge that the beam touches and then find the intersection
                // point at the rectangle edge and the beam's center line.

                if (isIntersecting) {
                  var circleCol = new h2d.col.Circle(
                      item.x, item.y, item.radius);
                  var trueIntersectionPts = circleCol
                    .lineIntersect(centerLine.p1, centerLine.p2);
                  // intersection point
                  var p = intersectionPoint;

                  var laserHitCdKey = 'kamehamehaHit';
                  if (!Cooldown.has(item.cds, laserHitCdKey)) {
                    final cooldownReduction = -tempState.get(tickKey) * 0.1;
                    Cooldown.set(
                        item.cds, 
                        laserHitCdKey, 
                        0.2 + cooldownReduction);
                    item.damageTaken += 1;
                  }

                  adjustedEndPt = p;

                  if (debug.endPos) {
                    // TODO: should be moved to a render method
                    Main.Global.sb.emitSprite(
                      x1,
                      y1,
                      'ui/square_white',
                      null,
                      (p) -> {
                        final scale = 10;

                        p.batchElement.scaleX = scale;
                        p.batchElement.scaleY = scale;
                      }
                    );

                    // TODO: should be moved to a render method
                    Main.Global.sb.emitSprite(
                      p.x,
                      p.y,
                      'ui/square_white',
                      null,
                      (p) -> {
                        final scale = 10;

                        p.batchElement.scaleX = scale;
                        p.batchElement.scaleY = scale;
                      }
                    );
                  };
                }

                return isIntersecting;
              }

              return false;
            }

            return !checkCollisions(obstacles) 
              && !checkCollisions(items);
          }
        );

        abilityEvents.push({
          type: 'KAMEHAMEHA',
          startPoint: startPt,
          endPoint: adjustedEndPt,
        });
      }

      case 2: {
        final cdKey = 'ability_spider_bot';

        if (Cooldown.has(cds, cdKey)) {
          return;
        }

        final cooldown = 0.2;
        final seekRange = 200;
        Cooldown.set(cds, 'recoveringFromAbility', 0.15);
        Cooldown.set(cds, cdKey, 0.2);

        final attackTargetFilterFn = (ent) -> {
          return ent.type == 'ENEMY';
        }

        for (_ in 0...3) {

          final player = this;
          final queryInterval = 30;
          final tickOffset = Utils.irnd(0, queryInterval);
          var cachedQuery: Map<Grid.GridKey, Grid.GridKey> 
            = null;
          final compareEntityByDistance = (
              entityId, 
              data: {
                ent: Entity,
                distance: Float,
                botRef: Entity
              }) -> {
            final ent = Entity.getById(entityId);

            if (ent.type != 'ENEMY') {
              return data;
            }

            final d = Utils.distance(
                data.botRef.x, data.botRef.y, ent.x, ent.y);

            if (d < data.distance) {
              data.ent = ent;
              data.distance = d;
            }

            return data;
          }

          final findNearestTarget = (botRef: Entity) -> {
            final shouldRefreshQuery = cachedQuery == null || (
                Main.Global.tickCount + tickOffset) % queryInterval == 0;
            cachedQuery = shouldRefreshQuery
              ? Grid.getItemsInRect(
                  Main.Global.dynamicWorldGrid,
                  botRef.x,
                  botRef.y,
                  seekRange,
                  seekRange)
              : cachedQuery;

            final nearestEnemy: Entity = Lambda.fold(
                cachedQuery,
                compareEntityByDistance, {
                  ent: null,
                  distance: Math.POSITIVE_INFINITY,
                  botRef: botRef
                }).ent;

            return nearestEnemy != null 
              ? nearestEnemy 
              : player;
          }

          // launch offset
          final lo = 8;
          final botRef = new Ai({
            x: x + Utils.irnd(-lo, lo),
            y: y + Utils.irnd(-lo, lo),
            radius: 8,
          }, 4, findNearestTarget, attackTargetFilterFn);
          botRef.type = 'FRIENDLY_AI';
        }
      }
    }
  }

  public override function render(time: Float) {
    var activeAnim: core.Anim.AnimRef;
    if (Cooldown.has(cds, 'recoveringFromAbility')) {
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
      core.Anim.getFrame(activeAnim, time),
      null,
      (p) -> {
        p.batchElement.scaleX = facingX;
      }
    );

    for (e in abilityEvents) {
      switch(e) {
        case { type: 'KAMEHAMEHA', 
          startPoint: startPt, 
          endPoint: endPt 
        }: {

          final laserHeadSpriteData = Reflect.field(
              Main.Global.sb.batchManager.spriteSheetData,
              'ui/kamehameha_head'
              );
          final laserHeadWidth = laserHeadSpriteData.frame.w;
          final tickPercent = Main.Global.tempState.get(
                'kamehamehaChanneling');
          final yScale = tickPercent + Utils.irnd(0, 1) * 0.125;
          
          // laser head
          final angle = Math.atan2(
              endPt.y - startPt.y,
              endPt.x - startPt.x);
          final vx = Math.cos(angle);
          final vy = Math.sin(angle);

          {
            Main.Global.sb.emitSprite(
                startPt.x, startPt.y,
                'ui/kamehameha_head',
                angle,
                (p) -> {
                  p.batchElement.scaleY = yScale;
                });
          }

          {
            var lcx = startPt.x + (vx * laserHeadWidth);
            var lcy = startPt.y + (vy * laserHeadWidth);
            var beamCallback = (p) -> {
              final b: h2d.SpriteBatch.BatchElement = 
                p.batchElement;

              b.scaleX = Math.round(
                  Utils.distance(lcx, lcy, endPt.x, endPt.y));
              b.scaleY = yScale; 
            };

            // laser center
            final angle = Math.atan2(
                endPt.y - lcy,
                endPt.x - lcx);

            Main.Global.sb.emitSprite(
                lcx, lcy,
                'ui/kamehameha_center_width_1',
                angle,
                beamCallback);
          }

          // laser tail
          {
            final angle = Math.atan2(
                endPt.y - endPt.y + vy,
                endPt.x - endPt.x + vx);

            Main.Global.sb.emitSprite(
                endPt.x, endPt.y,
                'ui/kamehameha_tail',
                angle,
                (p) -> {
                  p.batchElement.scaleX = 1 + 
                    Utils.irnd(0, 1) * 0.25;
                  p.batchElement.scaleY = yScale; 
                });
          }
        }

        default: {}
      }
    }
  }
}

class MapObstacle extends Entity {
  var meta: core.Types.TiledObject;

  public function new(props: EntityProps, meta) {
    super(props);
    type = 'OBSTACLE';
    forceMultiplier = 3.0;
    this.meta = meta;
  }

  public override function render(_) {
    Main.Global.sb.emitSprite(
      x, y, meta.name);
  }
}

// Spawns enemies over time
class EnemySpawner extends Entity {
  var enemiesLeftToSpawn: Int;
  var spawnInterval = 0.001;
  var isDormant = true;
  var findTarget: (self: Entity) -> Entity;

  public function new(
    x, y, numEnemies, parent: h2d.Object,
    findTarget
  ) {
    super({
      x: x,
      y: y,
      radius: 0
    });
    enemiesLeftToSpawn = numEnemies;
    cds = new Cooldown();
    this.parent = parent;
    this.x = x;
    this.y = y;
    this.findTarget = findTarget;
  }

  public override function update(dt: Float) {
    final target = findTarget(this);

    if (target == null) {
      return;
    }

    final distFromTarget = Utils.distance(x, y, target.x, target.y);

    if (distFromTarget < 450) {
      isDormant = false;
    }

    if (isDormant) {
      return;
    }

    final isDone = enemiesLeftToSpawn <= 0;
    if (isDone) {
      health = 0;
      return;
    } 

    Cooldown.update(cds, dt);

    if (Cooldown.has(cds, 'recentlySpawned')) {
      return;
    }

    Cooldown.set(cds, 'recentlySpawned', spawnInterval);
    enemiesLeftToSpawn -= 1;

    var size = Utils.irnd(1, 2);
    var radius = 3 + size * 6;
    var posRange = 20;
    var e = new Ai({
      x: x + Utils.irnd(-posRange, posRange),
      y: y + Utils.irnd(-posRange, posRange),
      radius: radius,
      weight: 1.0,
    }, size, findTarget);
    parent.addChildAt(e, 0);
  }
}

class MapData {
  static var cache: MapDataRef;
  static var previousTiledRes: hxd.res.Resource;

  static public function create(tiledRes: hxd.res.Resource) {
    if (previousTiledRes == tiledRes) {
      return cache;
    }

    // parse Tiled json file
    var mapData:TiledMapData = haxe.Json.parse(
        hxd.Res.level_intro_json.entry.getText());
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
  public var level = 2;
  var player: Player;
  var mousePointer: h2d.Object;
  var mousePointerSprite: h2d.Graphics;
  var mapRef: GridRef;
  var MOUSE_POINTER_RADIUS = 5.0;
  var enemySpawnerRefs: Array<EnemySpawner> = [];

  function calcNumEnemies(level: Int) {
    return level * Math.round(level /2);
  }

  public function isGameOver() {
    return player.health <= 0;
  }

  public function isLevelComplete() {
    for (e in Entity.ALL_BY_ID) {
      // enemies still remain, so level not complete
      if (e.type == 'ENEMY') {
        return false;
      }
    }
    return true;
  }

  public function cleanupLevel() {
    // reset game state
    for (entityRef in Entity.ALL_BY_ID) {
      entityRef.health = 0;
    }

    mousePointer.remove();
  }

  override function onRemove() {
    cleanupLevel();
    cleanupDisposedEntities();
  }

  public function newLevel(s2d: h2d.Scene) {
    level += 1;

    {
      final parsedTiledMap = MapData.create(
          hxd.Res.level_intro_json);
      final layersByName = parsedTiledMap.layersByName;
      final objectsRects: Array<core.Types.TiledObject> = 
        layersByName.get('objects').objects;
      final enemySpawnPoints = Lambda
        .filter(objectsRects, (item) -> {
          return item.type == 'enemySpawnPoint';
        });
      final spawnerFindTargetFn = (_) -> {
        return player;
      }

      enemySpawnerRefs = Lambda.map(
          enemySpawnPoints, 
          (point) -> {
            return new EnemySpawner(
                point.x,
                point.y,
                5,
                s2d,
                spawnerFindTargetFn);
          });  
    }


    // intro_boss
    {
      var parsedTiledMap = MapData.create(
          hxd.Res.level_intro_json);
      var layersByName = parsedTiledMap.layersByName;
      var mapObjects: Array<Dynamic> = 
        layersByName.get('objects').objects;
      var miniBossPos: Dynamic = Lambda.find(
          mapObjects, 
          (item) -> item.name == 'mini_boss_position');
      var size = 3;

      var e = new Ai({
        x: miniBossPos.x,
        y: miniBossPos.y,
        radius: 30,
        sightRange: 150,
        weight: 1.0,
      }, size, (_) -> player);
      Main.Global.rootScene.addChildAt(e, 0);
    }
  }

  // triggers a side-effect to change `canSeeTarget`
  public function lineOfSight(entity, x, y, i) {
    final cellSize = mapRef.cellSize;
    final isClearPath = Grid.isEmptyCell(
        Main.Global.obstacleGrid, x, y);
    final isInSightRange = i * cellSize <= 
      entity.sightRange;

    if (!isClearPath || !isInSightRange) {
      entity.canSeeTarget = false;
      return false;
    }

    entity.canSeeTarget = true;
    return isClearPath;
  }

  public function new(
    s2d: h2d.Scene,
    oldGame: Game
  ) {
    super();

    mapRef = Main.Global.obstacleGrid;
    var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
    var spriteSheetData = Main.Global.sb
      .batchManager.spriteSheetData;

    // load map background
    {
      var bgData = Reflect.field(
          spriteSheetData, 
          'ui/level_intro');
      var tile = spriteSheet.sub(
        bgData.frame.x,
        bgData.frame.y,
        bgData.frame.w,
        bgData.frame.h
      );
      var bmp = new h2d.Bitmap(tile, s2d);
    }

    var parsedTiledMap = MapData.create(
        hxd.Res.level_intro_json);
    var layersByName = parsedTiledMap.layersByName;
    var mapObjects: Array<Dynamic> = 
      layersByName.get('objects').objects;
    var playerStartPos: Dynamic = Lambda.find(
        mapObjects, 
        (item) -> item.name == 'player_start');

    Main.Global.rootScene = s2d;

    // setup traversible grid
    {
      var traversableRects: Array<Dynamic> = 
        layersByName.get('traversable').objects;
      var updateTraversableGrid = (item: TiledObject) -> {
        Grid.setItemRect(
          Main.Global.traversableGrid,
          (item.x + item.width / 2),
          (item.y + item.height / 2),
          item.width,
          item.height,
          Std.string(item.id)
        );
        return true;
      }
      Lambda.foreach(traversableRects, updateTraversableGrid);

      var debugTraversalGrid = false;
      if (debugTraversalGrid) {
        // debug traversable positions
        var traversableGridItems = Main.Global
          .traversableGrid.itemCache;
        var g = new h2d.Graphics(Main.Global.debugScene);
        g.beginFill(Game.Colors.yellow, 0.3);
        var cellSize = Main.Global.traversableGrid.cellSize;
        for (key => item in traversableGridItems) {
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

    // AGENDA: setup map pillars
    // setup environment obstacle colliders
    {
      final objectsRects: Array<core.Types.TiledObject> = 
        layersByName.get('objects').objects;
      final pillarObjects = Lambda
        .filter(objectsRects, (item) -> {
          return item.type == 'mapObject';
        });
      Lambda.foreach(pillarObjects, (item) -> {
        final spriteKey = item.name;
        final spriteData: SpriteBatchSystem.SpriteData = 
          Reflect.field(
              spriteSheetData, 
              spriteKey);
        final cx = item.x + item.width / 2;
        final pivotYOffset = Math.round(
            spriteData.pivot.y * spriteData.sourceSize.h);
        final cy = item.y - item.height
          + pivotYOffset;
        final radius = Std.int((item.width - 2) / 2);
        new MapObstacle({
          id: 'mapObstacle_${item.id}',
          x: cx,
          y: cy,
          radius: radius,
          avoidanceRadius: radius + 3
        }, item);
        return true;
      });
    }

    s2d.addChild(this);
    if (oldGame != null) {
      oldGame.cleanupLevel();
    }
    player = new Player(
      playerStartPos.x,
      playerStartPos.y - 6,
      s2d
    );
    s2d.addChildAt(player, 0);
    Camera.follow(Main.Global.mainCamera, player);

    var font: h2d.Font = hxd.res.DefaultFont.get().clone();
    font.resizeTo(24);

    // mouse pointer
    mousePointer = new h2d.Object(this);
    mousePointerSprite = new h2d.Graphics(mousePointer);
    mousePointerSprite.beginFill(0xffda3d, 0.3);
    mousePointerSprite.drawCircle(0, 0, MOUSE_POINTER_RADIUS);
  }

  function cleanupDisposedEntities() {
    for (a in Entity.ALL_BY_ID) {
      if (a.isDone()) {
        Entity.ALL_BY_ID.remove(a.id);
        Grid.removeItem(Main.Global.dynamicWorldGrid, a.id);
        Grid.removeItem(Main.Global.obstacleGrid, a.id);
        Grid.removeItem(Main.Global.lootColGrid, a.id);
        a.remove();
      }
    }
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    var isReady = mapRef != null;

    if (!isReady) {
      return;
    }

    // reset list before next loop
    Main.Global.entitiesToRender = [];

    PlayerStats.update(
        Main.Global.playerStats, 
        dt);

    for (ref in enemySpawnerRefs) {
      ref.update(dt);
    }

    Cooldown.update(SoundFx.globalCds, dt);

    cleanupDisposedEntities();

    var groupIndex = 0;
    for (a in Entity.ALL_BY_ID) {
      groupIndex += 1;
      // reset groupIndex
      if (groupIndex == 60) {
        groupIndex = 0;
      }

      final isDynamic = a.type == 'ENEMY'
        || a.type == 'FRIENDLY_AI'
        || a.type == 'PROJECTILE'
        || a.type == 'PLAYER';
      final isMoving = a.dx != 0 || a.dy != 0;
      final hasTakenDamage = a.damageTaken > 0;
      final isCheckTick = (Main.Global.tickCount + groupIndex) % 
        a.neighborCheckInterval == 0;
      final shouldFindNeighbors = {
        final isRecentlySummoned =  Cooldown.has(
            a.cds, 'recentlySummoned');
        final isActive = isMoving || hasTakenDamage;

        isDynamic && (
            isRecentlySummoned
            || (isCheckTick && isActive));
      }

      if (shouldFindNeighbors) {
        var neighbors: Array<String> = [];
        var nRange = 10;
        var height = a.radius * 2 + nRange;
        var width = height;
        var dynamicNeighbors = Grid.getItemsInRect(
            Main.Global.dynamicWorldGrid, a.x, a.y, width, height
            );
        var obstacleNeighbors = Grid.getItemsInRect(
            Main.Global.obstacleGrid, a.x, a.y, width, height
            );
        for (n in dynamicNeighbors) {
          if (n != a.id) {
            neighbors.push(n);
          }
        }
        for (n in obstacleNeighbors) {
          if (n != a.id) {
            neighbors.push(n);
          }
        }
        a.neighbors = neighbors;
      }

      // line of sight check
      var enemy:Dynamic = a;
      if (a.type == 'ENEMY' && enemy.follow != null) {
        final follow = enemy.follow;
        final dFromTarget = Utils.distance(a.x, a.y, follow.x, follow.y);
        final shouldCheckLineOfSight = dFromTarget <= 
          enemy.sightRange;

        if (shouldCheckLineOfSight) {
          final cellSize = mapRef.cellSize;
          final startGridX = Math.floor(a.x / cellSize);
          final startGridY = Math.floor(a.y / cellSize);
          final targetGridX = Math.floor(follow.x / cellSize);
          final targetGridY = Math.floor(follow.y / cellSize);

          Utils.bresenhamLine(
              startGridX, startGridY, targetGridX, 
              targetGridY, lineOfSight, enemy);
        } else {
          enemy.canSeeTarget = false;
        }
      }

      switch (a) {
        case 
          { type: 'PLAYER' } 
        | { type: 'ENEMY' } 
        | { type: 'FRIENDLY_AI' }: {
          Grid.setItemRect(
              Main.Global.dynamicWorldGrid,
              a.x,
              a.y,
              a.radius * 2,
              a.radius * 2,
              a.id);
        }
        case { type: 'OBSTACLE' }: {
          Grid.setItemRect(
              Main.Global.obstacleGrid,
              a.x,
              a.y,
              a.radius * 2,
              a.radius * 2,
              a.id);
        }
        case { type: 'LOOT' }: {
          Grid.setItemRect(
              Main.Global.lootColGrid,
              a.x,
              a.y,
              a.radius * 2,
              a.radius * 2,
              a.id);
        }
        default: {}
      }

      a.update(dt);

      final shouldRender = {
        final mc = Main.Global.mainCamera;
        final r = a.radius;
        final dxFromCam = Math.abs(a.x - mc.x) - r;
        final dyFromCam = Math.abs(a.y - mc.y) - r;
        final threshold = 50;

        dxFromCam <= mc.w / 2 + threshold
          && dyFromCam <= mc.h / 2 + threshold;
      }

      if (shouldRender) {
        Main.Global.entitiesToRender.push(a);
      }
    }

    mousePointer.x = s2d.mouseX;
    mousePointer.y = s2d.mouseY;

    // sync up scenes with the camera
    {
      Camera.setSize(
          Main.Global.mainCamera,
          Main.Global.rootScene.width,
          Main.Global.rootScene.height);

      // update scenes to move relative to camera
      var cam_center_x = -Main.Global.mainCamera.x 
        + Math.fround(Main.Global.rootScene.width / 2);
      var cam_center_y = -Main.Global.mainCamera.y 
        + Math.fround(Main.Global.rootScene.height / 2);
      for (scene in [
          Main.Global.rootScene,
          Main.Global.particleScene,
          Main.Global.debugScene
      ]) {
        scene.x = cam_center_x;
        scene.y = cam_center_y;
      }

      Camera.update(Main.Global.mainCamera, dt);
    }

    Hud.UiGrid.update(dt);
  }

  public function render(time: Float) {
    for (entityRef in Main.Global.entitiesToRender) {
      entityRef.render(time);
    }

    Hud.UiGrid.render(time);
  }
}
