/*
   * [ ] TODO: [HIGH PRIORITY]: Add an api for triggering damage to each entity within a given area. Right now we're using a bullet with a low lifetime to do this which is very hacky.
   * [ ] TODO: Add small amount of squash/stretch when an entity takes a hit
   * [ ] TODO: Add support for rectangular collisions on entities. This is
         especially important for walls but also useful for npcs that don't
         exactly fit within the shape of a circle.
   * [ ] TODO: Enemies should go after player when they take a hit and are 
         in line of sight.
   * [ ] TODO: Make pets follow player if they are 
         too far away from player. If they are a screen's distance
         away from player, teleport them nearby to player. This will
         also help prevent them from getting stuck in certain situations.
   * [ ] TODO: Add some basic pathfinding for ai (maybe flowfield?) so they're
         not getting stuck when trying to walk towards player even though
         they're clearly within vision. This can happen if there is a 
         long island in between the player and ai but the ai can clearly walk
         around that island. This will also improve their ability to
         maneuver around corners.
   * [ ] TODO: Adjust level_1 start point so that theres more open space at the
               teleportation point to give player freedom of movement. This is
               a ux thing so that player doesn't get frustrated early because
               they couldn't move around at the beginning.
*/

using core.Types;

import h2d.Bitmap;
import Grid;
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
  public static final itemModifier = 0x0095e9;
}

class Projectile extends Entity {
  public var damage = 1;
  public var lifeTime = 5.0;
  var collidedWith: Array<Entity> = [];
  var cFilter: EntityFilter;
  public var maxNumHits = 1;
  var numHits = 0;
  final speedModifier: EntityStats.EventObject;
  // the entity that this was created from
  public var source: Entity;

  public function new(
    x1: Float, y1: Float, x2: Float, y2: Float,
    speed = 0.0,
    radius = 10,
    collisionFilter
  ) {
    super({
      x: x1,
      y: y1,
      radius: radius,
    });
    type = 'PROJECTILE';
    stats = EntityStats.create({
      label: '@projectile',
      currentHealth: 1.,
    });
    speedModifier = {
      type: 'MOVESPEED_MODIFIER',
      value: speed
    };
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
    if (source == null) {
      throw new haxe.Exception(
          'source prop missing for $this');
    }

    super.update(dt);

    EntityStats.addEvent(
        stats, speedModifier);
    collidedWith = [];

    final alivePercent = Easing.progress(
        createdAt, Main.Global.time, lifeTime);
    if (alivePercent >= 1) {
      Entity.destroy(id);
    }

    for (id in neighbors) {
      final a = Entity.getById(id);
      if (cFilter(a)) {
        final d = Utils.distance(x, y, a.x, a.y);
        final min = radius + a.radius * 1.0;
        final conflict = Entity.intersectRect(this, a);
        if (conflict) {
          collidedWith.push(a);

          numHits += 1;

          if (numHits >= maxNumHits) {
            break;
          }
        }
      }
    }
  }
}

// query all entities within the area of effect (aoe)
class LineProjectile extends Projectile {
  public override function update(dt: Float) {
    super.update(dt);

    final damageEvent: EntityStats.EventObject = {
      type: 'DAMAGE_RECEIVED',
      value: {
        baseDamage: damage,
        sourceStats: source.stats
      }
    };
    for (ent in collidedWith) {
      EntityStats.addEvent(
          ent.stats, damageEvent);
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
  public var explodeWhenExpired = false;
  public var playSound = true;
  public var explosionScale = 1.;

  public function new(
    x1, y1, x2, y2, speed, 
    _spriteKey, collisionFilter
  ) {
    super(x1, y1, x2, y2, speed, 8, collisionFilter);
    lifeTime = 2.;
    spriteKey = _spriteKey;
  }

  public override function update(dt: Float) {
    super.update(dt);

    if (playSound && !launchSoundPlayed) {
      launchSoundPlayed = true;

      SoundFx.bulletBasic();
    }

    if (collidedWith.length > 0) {
      Entity.destroy(id);

      final baseDamage = 1;
      final damageEvent: EntityStats.EventObject = {
        type: 'DAMAGE_RECEIVED',
        value: {
          baseDamage: baseDamage,
          sourceStats: source.stats
        }
      };
      for (ent in collidedWith) {
        EntityStats.addEvent(
            ent.stats, damageEvent);
      }
    }

    if (isDone() && 
        explodeWhenExpired ||
        (!explodeWhenExpired && collidedWith.length > 0)) {

      core.Anim.AnimEffect.add({
        frames: onHitFrames,
        startTime: Main.Global.time,
        duration: 0.15,
        x: x,
        y: y,
        z: 10,
        scale: explosionScale,
        isLightSource: true
      }); 
    }
  }

  public override function render(time: Float) {
    super.render(time);
    final progress = Easing.easeInExpo(
        Easing.progress(
          createdAt, time, lifeTime));
    final angle = Math.atan2(
        y + dy - y,
        x + dx - x);
    final sprite = Main.Global.sb.emitSprite(
        x, y, spriteKey, angle);
    sprite.scale = 1 - progress;

    final lightSource = Main.lightingSystem.sb.emitSprite(
        x, 
        y, 
        spriteKey, 
        angle, 
        null);
    lightSource.alpha = 0.8;
    lightSource.scale = 1.7 * (1 - progress);
  }
}

class EnergyBomb extends Projectile {
  final initialSpeed = 250.;
  var launchSoundPlayed = false;

  public function new(
    x1, y1, x2, y2, cFilter
  ) {
    super(x1, y1, x2, y2, 
        0.0, 8, cFilter);
    radius = 4;
    lifeTime = 1.5;
  }

  public override function update(dt: Float) {
    super.update(dt);

    final moveDuration = 2.;
    final progress = Easing.easeOutExpo(
        (Main.Global.time - createdAt) / moveDuration);
    EntityStats.addEvent(
        stats, {
          type: 'MOVESPEED_MODIFIER',
          value: (1 - progress) * initialSpeed
        });

    if (!launchSoundPlayed) {
      launchSoundPlayed = true;

      // TODO: add sound
    }

    if (collidedWith.length > 0) {
      Entity.destroy(id);
    }

    // Trigger cluster explosion
    // Launches an explosion at the point of impact,
    // and several more in random locations near point
    // of impact 
    if (isDone()) {
      for (i in 0...5) {
        final explosionStart = Main.Global.time + i * 0.025;
        Main.Global.hooks.update.push((dt) -> {
          if (Main.Global.time < explosionStart) {
            return true;
          }

          final offsetRange = 20;
          final x2 = x + (i == 0 
            ? 0 
            : Utils.irnd(-offsetRange, offsetRange, true));
          final y2 = y + (i == 0 
            ? 0 
            : Utils.irnd(-offsetRange, offsetRange, true));
          final ref = new Bullet(
              x2, y2, 
              x2, y2,
              0, 
              'ui/placeholder',
              cFilter);
          ref.explodeWhenExpired = true;
          ref.source = this.source;
          ref.maxNumHits = 999999;
          ref.explosionScale = 1.6;
          ref.playSound = false;
          ref.radius = 20;
          ref.lifeTime = 0;
          Main.Global.rootScene
            .addChild(ref);

          return false;
        });
      } 
    }
  }

  public override function render(time: Float) {
    super.render(time);

    {
      final ringBurstDuration = 0.4;

      if (!Cooldown.has(cds, 'ringBurst')) {
        Cooldown.set(cds, 'ringBurst', ringBurstDuration);
      }

      Main.Global.sb.emitSprite(
          x, y, 
          'ui/energy_bomb_ring', 
          null, (p) -> {
            final b = p;
            final ringBurstCd = Cooldown.get(cds, 'ringBurst');
            // reduce alpha over time
            b.alpha = ringBurstCd / ringBurstDuration ;
            // increase scale over time
            b.scale = (ringBurstDuration - ringBurstCd) * 5;
          });
    }

    final angle = time * Math.PI * 8;
    final spriteKey = 'ui/energy_bomb_projectile';
    final scale = 1;
    final p = Main.Global.sb.emitSprite(
        x, y, 
        spriteKey, 
        angle);
    final v = 1 + Math.abs(Math.sin(time * 8 - createdAt)) * 10;
    p.g = v;
    p.b = v / 2;

    final light = Main.lightingSystem.sb.emitSprite(
        x, 
        y, 
        spriteKey, 
        angle);
    light.scale = scale * 2;
  }
}

typedef EntityFilter = (ent: Entity) -> Bool;

typedef AiProps = {
  > Entity.EntityProps,
  aiType: String
};

class Ai extends Entity {
  static final hitFlashDuration = 0.04;
  static final defaultFindTargetFn = (ent: Entity) -> {
    return Entity.NULL_ENTITY;
  };
  static final defaultAttackTargetFilterFn: EntityFilter = 
    (ent) -> {
      return ent.type == 'PLAYER' 
        || ent.type == 'OBSTACLE';
    };

  var font: h2d.Font = Fonts.primary();
  var damage = 0;
  public var follow: Entity;
  public var canSeeTarget = true;
  var spawnDuration: Float = 0.1;
  var debugCenter = false;
  var idleAnim: core.Anim.AnimRef;
  var runAnim: core.Anim.AnimRef;
  var activeAnim: core.Anim.AnimRef;
  public var sightRange = 200;
  public var attackTarget: Entity;
  var findTargetFn: (self: Entity) -> Entity;
  var attackTargetFilterFn: EntityFilter = 
    defaultAttackTargetFilterFn;

  public function new(
      props: AiProps, 
      ?findTargetFn, 
      ?attackTargetFilterFn) {
    super(props);
    traversableGrid = Main.Global.grid.traversable;
    final aiType = props.aiType;

    cds = new Cooldown();
#if debugMode
    if (!Config.enemyStats.exists(props.aiType)) {
      throw new haxe.Exception('invalid aiType `${props.aiType}`');
    }
#end
    Entity.setComponent(this, 'aiType', props.aiType);
    Entity.setComponent(this, 'neighborQueryThreshold', 10);
    Entity.setComponent(this, 'neighborCheckInterval', 10);
    Entity.setComponent(this, 'rarity', Utils.irnd(0, 2));

    status = 'UNTARGETABLE';
    final initialHealth = Config
      .enemyStats.get(props.aiType).health;
    stats = EntityStats.create({
      currentHealth: initialHealth,
      currentEnergy: 0,
      energyRegeneration: 0
    });
    avoidOthers = true;
    this.findTargetFn = Utils.withDefault(
        findTargetFn, defaultFindTargetFn);
    if (attackTargetFilterFn != null) {
      this.attackTargetFilterFn = attackTargetFilterFn;
    }

    if (props.sightRange != null) {
      sightRange = props.sightRange;
    }

    Cooldown.set(cds, 'recentlySummoned', spawnDuration);

    if (aiType == 'npcTestDummy') {
      idleAnim = {
        frames: [
          'ui/npc_test_dummy'
        ],
        duration: 1,
        startTime: Main.Global.time
      };

      runAnim = idleAnim;
      onDone = (self: Entity) -> {
        // respawn itself
        haxe.Timer.delay(() -> {
          new Ai({
            x: this.x,
            y: this.y,
            aiType: Entity.getComponent(this, 'aiType'),
            radius: this.radius
          });
        }, 400);
      }
    }

    if (aiType == 'bat') {
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

      final timeOffset = Utils.irnd(0, 100) / 100;
 
      idleAnim = {
        frames: idleFrames,
        duration: 1,
        startTime: Main.Global.time + timeOffset,
      }

      runAnim = {
        frames: idleFrames,
        duration: 0.5,
        startTime: Main.Global.time + timeOffset,
      };
    }

    if (aiType == 'botMage') {
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

    if (aiType == 'introLevelBoss') {
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

    if (aiType == 'spiderBot') {
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
    // damage render effect
    {
      var c = activeAnim;

      if (stats.damageTaken > 0) {
        Cooldown.set(cds, 'hitFlash', hitFlashDuration);
      }
    }

    super.update(dt);

    dx = 0.0;
    dy = 0.0;

    follow = findTargetFn(this);
    var origX = x;
    var origY = y;
    final aiMeta = Config.enemyStats.get(
        Entity.getComponent(this, 'aiType'));

    if (!Cooldown.has(cds, 'recentlySummoned')) {
      status = 'TARGETABLE';
      EntityStats.addEvent(
          stats,
          aiMeta.speed);
    }

    if (follow != null && !Cooldown.has(cds, 'attack')) {
      // distance to keep from destination
      var threshold = follow.radius + 5;
      var attackRange = aiMeta.attackRange;
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
            var separation = Math.sqrt(stats.moveSpeed / 4);
            var min = pt.radius + ept.radius + separation;
            var isColliding = d < min;
            if (isColliding) {
              var conflict = min - d;
              var adjustedConflict = Math.min(
                  conflict, conflict * 15 / stats.moveSpeed);
              var a = Math.atan2(ept.y - pt.y, ept.x - pt.x);
              // immobile entities have a stronger influence (obstacles such as walls, etc...)
              var multiplier = ept.forceMultiplier;
              var avoidX = Math.cos(a) * adjustedConflict * multiplier;
              var avoidY = Math.sin(a) * adjustedConflict * multiplier;

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
          final b: h2d.SpriteBatch.BatchElement = p;

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
        final attackType = aiMeta.attackType;

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
            b.source = this;
            Main.Global.rootScene.addChild(b);
          }

          case 'attack_self_detonate': {
            // explosion animation
            {
              final startTime = Main.Global.time;
              final duration = 0.3;
              core.Anim.AnimEffect.add({
                x: x + Utils.irnd(2, 2, true), 
                y: y + Utils.irnd(2, 2, true),
                z: 1,
                frames: [
                  'explosion_animation/default-0'
                ],
                startTime: startTime,
                duration: duration,
                effectCallback: (p) -> {
                  final b: h2d.SpriteBatch.BatchElement 
                    = p;
                  final aliveTime = Main.Global.time 
                    - startTime;
                  final progress = Easing
                    .easeInCirc(aliveTime / duration);

                  final scale = 1.2;
                  b.scale = scale - (scale * progress); 
                  b.alpha = 1 - progress;
                  b.g = 0.9 - progress * 0.5;
                  b.b = 0.7 - progress * 0.7;
                }
              });

              final duration = 0.2;
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
                    = p;
                  final aliveTime = Main.Global.time 
                    - startTime;
                  final progress = Easing
                    .easeInCirc(aliveTime / duration);

                  final scale = 0.7;
                  b.scale = scale - (scale * progress); 
                  b.alpha = 1 - Math.sqrt(progress);
                }
              });
            }

            Entity.destroy(id);
            final damageEvent: EntityStats.EventObject = {
              type: 'DAMAGE_RECEIVED',
              value: {
                baseDamage: 2,
                sourceStats: Entity.getById('PLAYER').stats
              }
            };
            EntityStats.addEvent(
                attackTarget.stats, damageEvent);
            final aoeSize = 30; // diameter
            // deal damage to other nearby enemies
            final nearbyEntities = Grid.getItemsInRect(
                Main.Global.grid.dynamicWorld,
                x, y, aoeSize, aoeSize);
            for (entityId in nearbyEntities) {
              final entityRef = Entity.getById(entityId);

              if (entityRef != attackTarget 
                  && attackTargetFilterFn(entityRef)) {
                EntityStats.addEvent(
                    attackTarget.stats, damageEvent);
              }
            }
          }

          case 'no_attack': {}

          default: {
#if !production
            throw 'invalid attack type `${attackType}`';
#end
          }
        }
      }
    }

    attackTarget = null;

    if (isDone()) {
      switch (deathAnimationStyle) {
        case 'default': {
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
            final duration = Utils.rnd(0.4, 0.7);
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
              frames: frames,
              isLightSource: true,
              lightScale: 2.,
            });
          }
        }

        default: {}
      }

      // log enemy kill action
      if (type == 'ENEMY') {
        final enemyType = Entity.getComponent(
            this, 'aiType');

        Session.logAndProcessEvent(
            Main.Global.gameState, 
            Session.makeEvent('ENEMY_KILLED', {
              enemyType: enemyType
            }));
      }
    }

    final currentFrameName = core.Anim.getFrame(
        activeAnim, Main.Global.time);
    collisionHitboxSpriteData = SpriteBatchSystem.getSpriteData(
        Main.Global.sb.batchManager.spriteSheetData,
        '${currentFrameName}--collision_hitbox');
  }

  public override function render(time: Float) {
    super.render(time);
    final currentFrameName = core.Anim.getFrame(
        activeAnim, time);

    // render character sprite
    {
      final sprite = Main.Global.sb.emitSprite(
          x, y,
          currentFrameName);
      // flash enemy white
      if (Cooldown.has(cds, 'hitFlash')) {
        sprite.r = 150;
        sprite.g = 150;
        sprite.b = 150;
      }

      sprite.scaleX = facingDir * 1;
      
      final shouldHighlight = Main.Global.hoveredEntity.id == id;
      if (shouldHighlight) {
        Entity.renderOutline(
            sprite.sortOrder - 1, currentFrameName, this);
      }
    }

    final lightSource = Main.lightingSystem.emitSpotLight(
        x, y, radius * 2.);
    lightSource.alpha = 0.2;
  }
}

class Aura {
  static final instancesByFollowId = new Map();

  public static function create(
      followId, 
      filterTypes: Map<String, Bool>) {
    final lifeTime = 0.5;
    final fromCache = instancesByFollowId.get(followId);
    final isCached = fromCache != null;
    final auraRadius = 100;
    final inst = isCached
      ? fromCache 
      : new Entity({
        x: 0,
        y: 0,
        type: 'moveSpeedAura',
        components: [
          'aiType' => 'aura',
          'neighborQueryThreshold' => auraRadius,
          'neighborCheckInterval' => 20,
          'isDynamic' => true,
          'checkNeighbors' => true,
        ]
      });
    Entity.setComponent(inst, 'lifeTime', lifeTime); 

    if (isCached) {
      return;
    }

    inst.stats = EntityStats.create({
      label: 'moveSpeedAura',
      currentHealth: 1.
    });
    instancesByFollowId.set(followId, inst);

    function sub(curVal: Float, dt: Float) {
      return curVal - dt;
    }

    Main.Global.hooks.update.push(function auraUpdate(dt) {
      final lifeTime = Entity.setWith(inst, 'lifeTime',
          sub, dt);

      if (lifeTime <= 0 || inst.isDone()) {
        instancesByFollowId.remove(followId);
        Entity.destroy(inst.id);
        return false;
      }

      Main.Global.logData.auraNeighborCount = inst.neighbors.length;
      final follow = Entity.getById(followId);
      inst.x = follow.x;
      inst.y = follow.y;
      final modifier: EntityStats.EventObject = {
        type: 'MOVESPEED_MODIFIER',
        value: 200
      };

      for (id in inst.neighbors) {
        final entityRef = Entity.getById(id);
        if (filterTypes.exists(entityRef.type)) {  
          final stats = entityRef.stats;
          EntityStats.addEvent(
              stats,
              modifier);
        }
      }

      return true;
    });

    Main.Global.hooks.render.push(function auraRender(time) {
      for (id in inst.neighbors) {
        final entityRef = Entity.getById(id);
        if (filterTypes.exists(entityRef.type)) {  
          final x = entityRef.x;
          final y = entityRef.y;
          final colorAdjust = Math.sin(Main.Global.time);
          final angle = Math.sin(Main.Global.time) * 4;

          {
            final p = Main.Global.sb.emitSprite(
                x, y,
                'ui/aura_glyph_1',
                angle);
            p.sortOrder = 2;
            p.r = 1.25 + 0.25 * colorAdjust;
            p.g = 1.25 + 0.25 * colorAdjust;
            p.b = 1.25 + 0.25 * colorAdjust;
            p.a = 0.4;
          }

          {
            final p = Main.Global.sb.emitSprite(
                x, y,
                'ui/aura_glyph_1',
                angle * -1);
            p.sortOrder = 2;
            p.scale = 0.8;
            p.r = 1.25 + 0.25 * colorAdjust;
            p.g = 1.25 + 0.25 * colorAdjust;
            p.b = 1.25 + 0.25 * colorAdjust;
            p.a = 0.8;
          }
        }
      }

      return Entity.exists(inst.id);
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
    ?startPoint: h2d.col.Point,
    ?endPoint: h2d.col.Point,
    ?targetId: Entity.EntityId
  }>;
  var facingX = 1;
  var facingY = 1;
  var activeAnim: core.Anim.AnimRef;

  public function new(x, y, s2d: h2d.Scene) {
    super({
      x: x,
      y: y,
      radius: 6,
      id: 'PLAYER'
    });
    type = 'PLAYER';
    forceMultiplier = 5.0;
    traversableGrid = Main.Global.grid.traversable;
    obstacleGrid = Main.Global.grid.obstacle;
    Entity.setComponent(this, 'neighborQueryThreshold', 100);

    rootScene = s2d;
    stats = EntityStats.create({
      maxHealth: 100,
      maxEnergy: 40,
      currentHealth: 100.0,
      currentEnergy: 40.0,
      energyRegeneration: 3, // per second
      pickupRadius: 50,
      lightRadius: 100
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

    // create orb companion
    {
      final initialOffsetX = 5;
      final ref = new Entity({
        x: x - initialOffsetX,
        y: y,
        radius: 5,
        id: 'PLAYER_PET_ORB'
      });
      ref.stats = EntityStats.create({
        currentHealth: 1,
      });

      final yOffset = 0;
      final MODE_FOLLOW = 'follow';
      final MODE_WANDER = 'wander';
      final state = {
        mode: MODE_WANDER,
        idleDuration: 0.,
        prevMove: {
          x: 0.,
          y: 0.
        },
      };
      var prevPlayerX = -1.;
      var prevPlayerY = -1.;

      Main.Global.hooks.update.push((dt) -> {
        state.mode = MODE_WANDER;

        final py = this.y + yOffset;
        final pSpeed = this.stats.moveSpeed;
        final distFromPos = Utils.distance(
            ref.x, ref.y,
            state.prevMove.x, state.prevMove.y);
        final speedDistThreshold = 20;
        final accel = distFromPos < speedDistThreshold
          ? -ref.stats.moveSpeed * 0.2
          : pSpeed * 0.1;
        final hasPlayerChangedPosition = 
          prevPlayerX != this.x
            || prevPlayerY != py;

        if (hasPlayerChangedPosition 
            || Cooldown.has(this.cds, 'recoveringFromAbility')) {
          state.mode = MODE_FOLLOW;
          state.idleDuration = 0;
        }

        final newSpeed = Utils.clamp(
            ref.stats.moveSpeed + accel,
            0,
            pSpeed);
        EntityStats.addEvent(
            ref.stats, {
              type: 'MOVESPEED_MODIFIER',
              value: newSpeed
            });

        if (state.mode == MODE_FOLLOW) {
          prevPlayerX = this.x;
          prevPlayerY = py;
          state.prevMove.x = prevPlayerX;
          state.prevMove.y = prevPlayerY;
        }

        if (state.mode == MODE_WANDER) {
          state.idleDuration += dt;
        } 

        if (state.mode == MODE_WANDER 
            && state.idleDuration > 1
            && !Cooldown.has(cds, 'petOrbWander')) {
          Cooldown.set(cds, 'petOrbWander', Utils.irnd(2, 3));
          final wanderDist = 50;
          final randX = this.x + Utils.irnd(-wanderDist, wanderDist, true);
          final randY = py + Utils.irnd(-wanderDist, wanderDist, true);

          state.prevMove.x = randX;
          state.prevMove.y = randY;
        }

        final angleToPos = Math.atan2(
            state.prevMove.y - ref.y,
            state.prevMove.x - ref.x);

        ref.dx = Math.cos(angleToPos);
        ref.dy = Math.sin(angleToPos);

        return !this.isDone();
      });

      ref.renderFn = (ref, time) -> {
        final timeOffset = 1.5;
        final yOffset = Math.sin(time + timeOffset) * 2;
        final base = Main.Global.sb.emitSprite(
            ref.x,
            ref.y,
            'ui/player_pet_orb');
        final facingX = ref.dx > 0 ? 1 : -1;
        // set the offset after so the shadow
        // sprite doesn't use the same initial y position
        base.y += yOffset;
        base.scaleX = facingX;
      };

      ref;
    }
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

    if (dy != 0) {
      facingY = dy > 0 ? 1 : -1;
    }

    var magnitude = Math.sqrt(dx * dx + dy * dy);
    var dxNormalized = magnitude == 0 
      ? dx : (dx / magnitude);
    var dyNormalized = magnitude == 0 
      ? dy : (dy / magnitude);

    dx = dxNormalized;
    dy = dyNormalized;
    EntityStats.addEvent(
        stats, {
          type: 'MOVESPEED_MODIFIER',
          value: 100,
        });
  }

  public override function update(dt) {
    super.update(dt);
    abilityEvents = [];

    PassiveSkillTree.eachSelectedNode(
        Main.Global.gameState,
        function updatePlayerStats(nodeMeta) {
          final modifier = nodeMeta.data.statModifier;

          if (modifier != null) {
            EntityStats.addEvent(
                stats,
                modifier);
          }
        });

    dx = 0;
    dy = 0;

    // collision avoidance
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

      if (entity.type == 'OBSTACLE') {
        final isBehind = y < entity.y;
        if (isBehind) {
          Entity.setComponent(this, 'isObscured', true);
          Entity.setComponent(entity, 'isObscuring', true);
        }
      }
    }

    useAbility();

    if (!Cooldown.has(cds, 'recoveringFromAbility')) {
      movePlayer();
    }

    final equippedAbilities = Hud.InventoryDragAndDropPrototype
      .getEquippedAbilities();
    final abilitiesByType = [
      for (lootId in equippedAbilities) {
        if (lootId == null) {
          continue;
        }

        final lootInst = Hud.InventoryDragAndDropPrototype
          .getItemById(lootId);
        final def = Loot.getDef(lootInst.type);

        lootInst.type => def;
      }
    ];

    if (abilitiesByType.exists('moveSpeedAura')) {
      Aura.create(this.id, [
          'FRIENDLY_AI' => true,
          'PLAYER' => true
      ]);
    }

    if (stats.forceField.damageTaken > 0) {
      Cooldown.set(
          this.cds,
          'forceFieldAbsorbedDamage', 
          0.15);
    }

    // update active anim
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

    final currentSprite = core.Anim.getFrame(
        activeAnim, Main.Global.time);
    collisionHitboxSpriteData = SpriteBatchSystem.getSpriteData(
        Main.Global.sb.batchManager.spriteSheetData,
        '${currentSprite}--collision_hitbox');
  }

  public function useAbility() {
    final preventAbilityUse = 
         Cooldown.has(cds, 'recoveringFromAbility') 
      || Cooldown.has(cds, 'playerCanPickupItem') 
      || Main.Global.hasUiItemsEnabled();

    if (preventAbilityUse) {
      return;
    }
    
    final abilitySlotIndexByMouseBtn = [
      -1 => -1,
      0 => 0,
      1 => 1,
      2 => -1,
      3 => 2,
      4 => 3
    ];
    final abilitySlotIndex = abilitySlotIndexByMouseBtn[
      Main.Global.worldMouse.buttonDown];
    final x2 = Main.Global.rootScene.mouseX;
    final y2 = Main.Global.rootScene.mouseY;
    // player's pivot is at their feet, this adjusts the
    // ability launch point to be roughly at player's torso
    final yCenterOffset = -10;
    final startY = y + yCenterOffset;
    final launchOffset = 12;
    final angle = Math.atan2(y2 - startY, x2 - x);
    final x1 = x + Math.cos(angle) * launchOffset;
    final y1 = startY + Math.sin(angle) * launchOffset;
    final x1_1 = x + Math.cos(angle) * launchOffset * 1.1;
    final y1_1 = startY + Math.sin(angle) * launchOffset * 1.1;

    final actionDx = Math.cos(Math.atan2(y2 - y, x2 - x));

    if (actionDx != 0) {
      facingX = actionDx > 0 ? 1 : -1;
    }

    final equippedAbilities = Hud.InventoryDragAndDropPrototype
      .getEquippedAbilities();

    final lootId = equippedAbilities[abilitySlotIndex];

    if (lootId == null) {
      return;
    }

    final lootInst = Hud.InventoryDragAndDropPrototype
      .getItemById(lootId);
    final lootDef = Loot.getDef(lootInst.type);
    var energyCost = lootDef.energyCost;
    var hasEnoughEnergy = energyCost 
      <= Entity.getById('PLAYER').stats.currentEnergy;
    final cooldownKey = 'ability__${lootInst.type}';
    var isUnavailable = Cooldown.has(cds, cooldownKey) 
      || !hasEnoughEnergy;

    if (isUnavailable) {
      return;
    }

    attackAnim.startTime = Main.Global.time;

    Cooldown.set(cds, 'recoveringFromAbility', lootDef.actionSpeed);
    Cooldown.set(cds, cooldownKey, lootDef.cooldown);
    EntityStats.addEvent(
        Entity.getById('PLAYER').stats, 
        { type: 'ENERGY_SPEND',
          value: energyCost });

    switch lootInst.type {
      case 'basicBlaster': {
        final ref = new Bullet(
            x1,
            y1,
            x1_1,
            y1_1,
            250.0,
            'ui/bullet_player_basic',
            (ent) -> (
              ent.type == 'ENEMY' || 
              ent.type == 'OBSTACLE' ||
              ent.type == 'BREAKABLE_PROP'));
        ref.lifeTime = 1.2;
        ref.source = this;
      }

      case 'basicBlasterEvolved': {
        final collisionFilter = (ent) -> (
            ent.type == 'ENEMY' || 
            ent.type == 'OBSTACLE' ||
            ent.type == 'BREAKABLE_PROP');
        for (_angle in [
          angle,
          angle - Math.PI / 10,
          angle + Math.PI / 10,
        ]) {
          final ref = new Bullet(
              x + Math.cos(_angle) * launchOffset,
              startY + Math.sin(_angle) * launchOffset,
              x + Math.cos(_angle) * launchOffset * 1.1,
              startY + Math.sin(_angle) * launchOffset * 1.1,
              250.0,
              'ui/bullet_player_basic',
              collisionFilter);
          final isSideShot = _angle != angle;
          ref.lifeTime = isSideShot 
            ? 0.7 
            : 1.;
          ref.source = this;
        }
      }

      case 'channelBeam': {
        // push render event
        final targetId = Ability.ChannelBeam
          .run(this, function collisionFilter(id: Entity.EntityId) {
            final type = Entity.getById(id).type;
            return switch(type) {
              case 
                  'ENEMY' 
                | 'OBSTACLE' 
                | 'BREAKABLE_PROP': 
                true;

              default: false;
            };
          });
        final beamBounds = Ability.ChannelBeam.getBeamBounds();
        final dx = Math.cos(beamBounds.angle);
        final dy = Math.sin(beamBounds.angle);
        final startPt = new h2d.col.Point(
            this.x + dx * launchOffset,
            this.y + (dy * launchOffset) + yCenterOffset);
        final targetRef = Entity.getById(targetId);
        final endPt = Entity.isNullId(targetId) 
          ? new h2d.col.Point(
              startPt.x + dx * Ability.ChannelBeam.maxLength,
              startPt.y + dy * Ability.ChannelBeam.maxLength)
          : new h2d.col.Point(
              targetRef.x,
              targetRef.y);

        abilityEvents.push({
          type: 'KAMEHAMEHA',
          startPoint: startPt,
          endPoint: endPt,
          targetId: targetId
        });
      }

      // TODO: Bots damage is currently hard coded
      case 'spiderBots': {
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
                  Main.Global.grid.dynamicWorld,
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
            aiType: 'spiderBot',
          }, findNearestTarget, attackTargetFilterFn);
          botRef.type = 'FRIENDLY_AI';
          botRef.deathAnimationStyle = 'none';
        }
      }

      case 'energyBomb': {
        final collisionFilter = (ent) -> (
            ent.type == 'ENEMY' || 
            ent.type == 'OBSTACLE' ||
            ent.type == 'BREAKABLE_PROP');
        var b = new EnergyBomb(
            x1,
            y1,
            x1_1,
            y1_1,
            collisionFilter);
        b.source = this;
        Main.Global.rootScene.addChild(b);
      }

      case 'heal1': {
        EntityStats.addEvent(
            Entity.getById('PLAYER').stats,
            { type: 'LIFE_RESTORE',
              value: 15,
              duration: 4,
              createdAt: Main.Global.time });
      }

      case 'energy1': {
        EntityStats.addEvent(
            Entity.getById('PLAYER').stats,
            { type: 'ENERGY_RESTORE',
              value: 8,
              duration: 3,
              createdAt: Main.Global.time });
      }

      case 'burstCharge': {
        final state = {
          isDashComplete: false,
        };
        final oldPos = {
          x: this.x,
          y: this.y
        };
        final startTime = Main.Global.time;
        final startTime = Main.Global.time;
        final duration = 0.4;
        final startedAt = Main.Global.time;
        final angle = Math.atan2(
            y2 - this.y,
            x2 - this.x);
        final maxDist = Utils.clamp(
            Utils.distance(
              this.x, this.y, x2, y2),
            0,
            100);
        final dx = Math.cos(angle);
        final dy = Math.sin(angle);
        final randOffset = Utils.irnd(0, 10);
        final trailFacingX = this.facingX;
        final trailDuration = 0.4;

        function renderTrail(
            percentDist: Float, 
            initialAlpha: Float,
            spriteKey) {
          core.Anim.AnimEffect.add({
            x: this.x,
            y: this.y,
            startTime: startTime,
            duration: trailDuration,
            frames: [
              spriteKey
            ],
            effectCallback: (p) -> {
              final progress = (Main.Global.time - startTime) 
                / trailDuration;
              final elem = p;
              elem.alpha = initialAlpha * (1 - progress);
              elem.scaleX = trailFacingX;
              elem.r = 1.;
              elem.g = 20.;
              elem.b = 20.;
            },
            isLightSource: true,
            lightScale: 1.1
          });
        }

        final duration = .1;
        final trailFns = [
            () -> renderTrail(0.0, 0.1, 'player_animation/run-0'),
            () -> renderTrail(0.2, 0.4, 'player_animation/run-1'),
            () -> renderTrail(0.3, 0.7, 'player_animation/run-2'),
            () -> renderTrail(0.5, 0.9, 'player_animation/run-3'),
            () -> renderTrail(0.8, 1., 'player_animation/run-4')
        ];
        for (trailIndex in 0...trailFns.length) {
          final startedAt = Main.Global.time; 

          Main.Global.hooks.update.push((dt) -> {
            final timeElapsed = Main.Global.time - startedAt;
            final triggerAnimationAt = trailIndex * duration / trailFns.length;

            if (timeElapsed >= triggerAnimationAt) {
              trailFns[trailIndex]();
              return false;
            }

            return true;
          }); 
        }

        // burst hit offset position
        final xOffset = 10;
        final yOffset = -8;

        function isSameSign(a: Float, b: Float) {
          return (a < 0 && b < 0) ||
            (a > 0 && b > 0);
        }

        // handle lunge effect
        Main.Global.hooks.update.push((dt) -> {
          final aliveTime = Main.Global.time - startedAt;
          final progress = aliveTime / duration;

          this.dx = dx;
          this.dy = dy;
          final distanceTraveled = Utils.distance(
              this.x,
              this.y,
              oldPos.x,
              oldPos.y);
          Entity.setComponent(this, 'alpha', 0.2);
          
          final hasCollisions = Entity.getCollisions(
              this.id, 
              this.neighbors,
              (ref) -> {
                if (ref.type == 'FRIENDLY_AI') {
                  return false;
                }

                final angle = Math.atan2(
                    ref.y - oldPos.y,
                    ref.x - oldPos.x);
                final isWithinPath = isSameSign(dx, Math.cos(angle)) &&
                  isSameSign(dy, Math.sin(angle));

                return isWithinPath;
              }).length > 0;

          state.isDashComplete = hasCollisions 
            || distanceTraveled >= maxDist
            || progress >= 1;

          if (state.isDashComplete) {
            Entity.setComponent(this, 'alpha', 1);

            final hitX = this.x + dx * launchOffset;
            final hitY = this.y + dy * launchOffset;
            final ref = new Bullet(
              hitX,
              hitY,
              hitX,
              hitY,
              0,
              'ui/placeholder',
              (ent) -> {
                return ent.type == 'ENEMY' ||
                  ent.type == 'BREAKABLE_PROP';
              }
            );

            ref.source = this;
            ref.maxNumHits = 999999;
            // ref.explosionScale = 1.6;
            ref.playSound = false;
            ref.radius = 20;
            ref.lifeTime = 0.1;
            ref.damage = 3;

            return false;
          } else {
            EntityStats.addEvent(
                this.stats, {
                  type: 'MOVESPEED_MODIFIER',
                  value: 500
                });
          }

          return true;
        });


        function setColor(
            ref: SpriteBatchSystem.SpriteRef,
            r = 1., g = 1., b = 1., a = 1.) {

          final elem = ref;

          elem.r = r;
          elem.g = g;
          elem.b = b;
          elem.a = a;
        }

        Main.Global.hooks.render.push((time) -> {
          final duration = 0.35;
          final aliveTime = Main.Global.time - startedAt;
          final progress = (aliveTime) 
            / duration;
          final endX = this.x;
          final endY = this.y;

          if (!state.isDashComplete) {
            return true;
          }

          final posV = Easing.easeInCirc(progress);
          final facingX = dx > 0 ? 1 : -1;
          final spriteRef = Main.Global.sb.emitSprite(
              endX + xOffset * facingX + dx * randOffset * posV, 
              endY + yOffset + dy * randOffset * posV,
              'ui/melee_burst');
          spriteRef.sortOrder = y + 10;

          if (aliveTime < 0.2) {
            final ref = Main.Global.sb.emitSprite(
              endX + xOffset * facingX + dx * randOffset * posV * 0.3, 
              endY + yOffset + dy * randOffset * posV * 0.3,
              'ui/melee_burst');

            ref.sortOrder = spriteRef.sortOrder + 1;
            setColor(ref, 10, 10, 10);
          } else {
            final b = spriteRef;
            b.scale = 1 + Easing.easeInCirc(progress) * 0.3;
            b.alpha = 1 - Easing.easeInSine(progress);
          }

          final isAlive = progress < 1;

          return isAlive;
        });
      }

      case 'flameTorch': {
        function triggerAbility(
            x1: Float,
            y1: Float,
            sortOffset: Float,
            angle) {

          final startTime = Main.Global.time;
          final numParticles = 10;

          for (i in 
              -Std.int(numParticles / 2)...Std.int(numParticles / 2)) {
            final spreadAngle = Math.PI / 6;
            final angle2 = angle + 
              i * spreadAngle / numParticles
              + (Utils.irnd(-4, 4) * Math.PI / 30);
            final speed = 10 + Utils.irnd(-10, 10);
            final rotation = Math.PI * (0.25 + Utils.rnd(0, .15));
            final duration = 0.4 + Utils.rnd(-0.3, 0.3);

            core.Anim.AnimEffect.add({
              x: x1,
              y: y1,
              startTime: startTime,
              frames: [
                'ui/square_glow', 
              ],
              duration: duration,
              isLightSource: true,
              effectCallback: (p) -> {
                final progress = (Main.Global.time - startTime) 
                  / duration;
                final elem = p;
                final dx = Math.cos(angle2);
                final dy = Math.sin(angle2);
                final v1 = Easing.easeOutQuint(progress);
                final v2 = Easing.easeInQuint(progress);
                final gravity = 9;

                p.sortOrder = y1 + sortOffset + 2;
                elem.alpha = 1 - Easing.easeInQuint(progress);
                elem.scale = 2 * (1 - Easing.easeInQuint(progress));
                elem.x += dx * -1 * speed * v1;
                elem.y += dy * -1 * speed * v1 + (gravity * v2);
                elem.rotation = rotation;

                elem.g = Math.max(0.4, 1 - v2 / 1.5);
                elem.b = 1 - v2 * 2;
              }
            });

          }

          // render torch
          final torchDuration = 0.2;
          core.Anim.AnimEffect.add({
            x: x1,
            y: y1,
            startTime: startTime,
            frames: [
              'ui/flame_torch', 
            ],
            duration: torchDuration,
            isLightSource: true,
            lightScale: 1.2,
            effectCallback: (p) -> {
              final progress = (Main.Global.time - startTime) 
                / torchDuration;
              final v1 = Easing.easeOutQuint(progress);
              final v2 = Easing.easeInQuint(progress);
              final elem = p;

              p.sortOrder += sortOffset + 1;
              elem.rotation = angle;
              // elem.scaleY = 1 - v2;
              elem.scaleX = 1 - v2;
              elem.alpha = 1 - v2;
            }
          });

          // muzzle flash
          core.Anim.AnimEffect.add({
            x: x1,
            y: y1,
            startTime: startTime,
            frames: [
              'ui/circle_gradient', 
            ],
            duration: torchDuration,
            isLightSource: true,
            effectCallback: (p) -> {
              final progress = (Main.Global.time - startTime) 
                / torchDuration;
              final v1 = Easing.easeInQuint(progress);
              final elem = p;

              p.sortOrder += sortOffset + 2;
              elem.rotation = angle;
              elem.scaleY = 1 - v1;
              elem.scaleX = 1 - v1;
              elem.alpha = 1 - v1;
            }
          });
        }

        final angle = Math.atan2(
            y1_1 - y1,
            x1_1 - x1);

        triggerAbility(
            x1_1,
            y1_1,
            yCenterOffset * -1,
            angle);

        // final hitList = new Map();

        final collisionFilter = (e: Entity) -> {
          return switch (e.type) {
            case 
                'ENEMY'
              | 'BREAKABLE_PROP': {
                true;
              }

            default: false;
          }
        };

        for (_ in 0...1) {
          final hitRef = new LineProjectile(
              x1,
              y1,
              x1_1,
              y1_1,
              400,
              10,
              collisionFilter);
          hitRef.source = this;
          hitRef.maxNumHits = 9999;
          hitRef.lifeTime = 0.05;
        }
      }

      case 'forceField': {
        EntityStats.addEvent(stats, {
          type: 'MAKE_FORCEFIELD',
          value: {
            life: 10,
            percentAbsorb: .5
          }
        });
        Cooldown.set(
            this.cds,
            'newForceField',
            0.3);
      }
    }
  }

  public override function render(time: Float) {
    super.render(time);
    final currentSprite = core.Anim.getFrame(activeAnim, time);
    function spriteEffect(p: SpriteBatchSystem.SpriteRef) {
      p.scaleX = facingX;
      p.alpha = Utils.withDefault(
          Entity.getComponent(this, 'alpha'),
          1);
    }
    // render player sprite
    final baseSprite = Main.Global.sb.emitSprite(
      x, y,
      currentSprite,
      null,
      spriteEffect
    );

    Main.lightingSystem.emitSpotLight(x, y, stats.lightRadius);

    final obscuredSilhouetteSprite = 
      Main.Global.oeSpriteBatch.emitSprite(
          x, y,
          currentSprite,
          null,
          spriteEffect);

    // render heal animation
    final isPlayerRestoringHealth = Lambda.exists(
        stats.recentEvents,
        (ev) -> ev.type == 'LIFE_RESTORE');
    final isPlayerRestoringEnergy = Lambda.exists(
        stats.recentEvents,
        (ev) -> ev.type == 'ENERGY_RESTORE');
    final isPlayerHealing = isPlayerRestoringHealth
      || isPlayerRestoringEnergy;

    function setSpriteColors(
        p, r = 1., g = 1., b = 1., a = 1.) {
      final e: h2d.SpriteBatch.BatchElement = p;

      e.r = r;
      e.g = g;
      e.b = b;
      e.a = a;
    };

    function healAnimation(healType, timeOffset) {
      final sb = Main.Global.sb;
      final spriteData = SpriteBatchSystem.getSpriteData(
          sb.batchManager.spriteSheetData,
          currentSprite);
      final orbSpriteData = SpriteBatchSystem.getSpriteData(
          sb.batchManager.spriteSheetData,
          'ui/player_pet_orb');
      final animDuration = 1.;
      final orbSpriteRef = Entity.getById('PLAYER_PET_ORB');

      // draw scan lines
      final numLines = 3;
      for (i in 0...numLines) {
        final tOffset = animDuration / numLines * i + timeOffset;
        final progress = ((time + tOffset) % animDuration) / animDuration;
        final yOffset = spriteData.pivot.y * spriteData.frame.h * (1 - progress);
        final orbSpriteY = orbSpriteRef.y
          - orbSpriteData.sourceSize.h 
          * orbSpriteData.pivot.y
          + (orbSpriteData.sourceSize.h / 2);
        final orbSpriteX = orbSpriteRef.x;
        final y2 = y + (1 - spriteData.pivot.y);
        final dy = -spriteData.pivot.y 
          * spriteData.sourceSize.h 
          * progress;
        final lineLength = Utils.distance(
            orbSpriteX,
            orbSpriteY,
            x,
            y2 + dy);
        final orbLineAngle = Math.atan2(
          (y2 + dy) - orbSpriteY,
          x - orbSpriteX);
        // render line
        final ray = sb.emitSprite(
            orbSpriteX,
            orbSpriteY,
            'ui/square_white',
            orbLineAngle);
        ray.sortOrder += 50.;
        ray.scaleX = lineLength;

        if (healType == 'LIFE_RESTORE') {
          setSpriteColors(ray, 0.6, 4., 0.8, 0.4);
        }

        if (healType == 'ENERGY_RESTORE') {
          setSpriteColors(ray, 0.6, 0.8, 4., 0.4);
        }

        final spriteRef = sb.emitSprite(
            x,
            y2,
            'ui/placeholder'); 
        final playerTile = sb.batchManager.spriteSheet
          .sub(spriteData.frame.x
              ,spriteData.frame.y + yOffset
              ,spriteData.frame.w
              ,1.5);
        playerTile.dx = -spriteData.pivot.x * spriteData.sourceSize.w;
        playerTile.dy = dy;
        final b = spriteRef;
        b.t = playerTile;
        b.scaleX = this.facingX;


        if (healType == 'LIFE_RESTORE') {
          setSpriteColors(spriteRef, 0.7, 4., 0.8, 0.9);
        }

        if (healType == 'ENERGY_RESTORE') {
          setSpriteColors(spriteRef, 1.3, 1.7, 2., 0.9);
        }
      }
    }

    if (isPlayerRestoringHealth) {
      healAnimation('LIFE_RESTORE', 0);
    }

    if (isPlayerRestoringEnergy) {
      healAnimation('ENERGY_RESTORE', 0.25);
    }

    // render abilities
    for (e in abilityEvents) {
      switch(e) {
        case { 
          type: 'KAMEHAMEHA', 
          startPoint: startPt, 
          endPoint: endPt,
          targetId: tid
        }: {
          Ability.ChannelBeam.renderLaser(
              Entity.getById('PLAYER'),
              startPt,
              endPt,
              Entity.getById(tid));
        }

        default: {}
      }
    }

    final hasForceField = stats.forceField.life > 0;
    if (hasForceField) {
      final ffSprite = Main.Global.sb.emitSprite(
          x,
          y,
          'ui/forcefield');
      final initProgress = Easing.easeOutBack(
            Cooldown.get(
              this.cds,
              'newForceField') / 0.3);
      final initialScale = 1 + initProgress * -0.4;
      ffSprite.sortOrder = baseSprite.sortOrder - 1;

      final blendProgress = Easing.easeInExpo(
          Cooldown.get(
            this.cds, 
            'forceFieldAbsorbedDamage') / 0.15);
      ffSprite.r = 1 + blendProgress * 1.;
      ffSprite.g = 1 + blendProgress * 1.;
      ffSprite.b = 1 + blendProgress * 1.;
      ffSprite.a = (1 + blendProgress * 10.) * (1 - 0.5 * initProgress);
      ffSprite.scale = initialScale - blendProgress * 0.05;
    }
  }
}

class MapObstacle extends Entity {
  var meta: {
    spriteKey: String
  } = null;

  public function new(props: EntityProps, meta) {
    super(props);
    type = 'OBSTACLE';
    forceMultiplier = 3.0;
    this.meta = meta;
  }

  public override function render(_) {
    super.render(_);
    Main.Global.sb.emitSprite(
      x, y, meta.spriteKey);
  }
}

// Spawns enemies over time
class EnemySpawner extends Entity {
  static final enemyTypes = [
    'bat',
    'botMage'
  ];

  static final sizeByEnemyType = [
    'bat' => 1,
    'botMage' => 2
  ];

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
    type = 'ENEMY_INVISIBLE_SPAWNER';
    this.parent = parent;
    this.x = x;
    this.y = y;
    this.findTarget = findTarget;

    stats = EntityStats.create({
      label: '@EnemySpawner',
      currentHealth: 1.,
    });
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
      Entity.destroy(this.id);
      return;
    } 

    if (Cooldown.has(cds, 'recentlySpawned')) {
      return;
    }

    Cooldown.set(cds, 'recentlySpawned', spawnInterval);
    enemiesLeftToSpawn -= 1;

    final enemyType = Utils.rollValues(enemyTypes);
    final size = sizeByEnemyType[enemyType];
    final radius = 3 + size * 6;
    final posRange = 20;
    new Ai({
      x: x + Utils.irnd(-posRange, posRange),
      y: y + Utils.irnd(-posRange, posRange),
      radius: radius,
      aiType: enemyType,
      type: 'ENEMY'
    }, findTarget);
  }
}

class Game extends h2d.Object {
  var mapRef: GridRef;
  var MOUSE_POINTER_RADIUS = 5.0;
  var finished = false;

  override function onRemove() {
    // reset game state
    for (entityRef in Entity.ALL_BY_ID) {
      Entity.deAlloc(entityRef.id);
    }

    finished = true;
  }

  public function newLevel(s2d: h2d.Scene) {
    final processMap = (
        fileName, 
        mapData: Editor.EditorState) -> {

      final editorConfig = Editor.getConfig(fileName);
      final cellSize = Main.Global.grid.traversable.cellSize;
      final spawnerFindTargetFn = (_) -> {
        return Entity.getById('PLAYER');
      }
      final spriteSheetTile =
        hxd.Res.sprite_sheet_png.toTile();
      final spriteSheetData = Utils.loadJsonFile(
          hxd.Res.sprite_sheet_json).frames;
      final layersToIgnore = [
        'layer_prefab',
        'layer_marquee_selection'
      ];
      final orderedLayers = Lambda.filter(
          mapData.layerOrderById,
          (layerId) -> {
            return !Lambda.exists(
                layersToIgnore, 
                (l) -> l == layerId);
          });
      final tileGridByLayerId = {
        final tileGrids = new Map();

        for (layerId in orderedLayers) {
          tileGrids.set(layerId, Grid.create(cellSize));
        }

        tileGrids;
      };
      final traversableGrid = Grid.create(cellSize);
      Main.Global.grid.traversable = traversableGrid;
      final truePositionByItemId = new Map<String, {x: Int, y: Int}>();

      final addToTileGrid = (
          tileGrid, x: Int, y: Int, itemId) -> {
        Grid.setItemRect(
            tileGrid,
            x, 
            y,
            tileGrid.cellSize,
            tileGrid.cellSize,
            itemId);
        truePositionByItemId.set(
            itemId, 
            { x: x, 
              y: y });
      }

      final miniMapScale = 1/6;
      final miniMap = {
        final miniMapMargin = 10;
        final miniMapSize = 200;
        final root = new h2d.Object(Main.Global.scene.uiRoot);
        final mask = new h2d.Mask(
            miniMapSize, 
            miniMapSize, 
            root);
        final bg = new h2d.Graphics(root);
        bg.beginFill(0x000000, 0.1);
        bg.drawRect(
            0, 0, miniMapSize, miniMapSize);
        final borderWidth = Hud.rScale;
        // draw borders
        bg.beginFill(0xfffffff, 0);
        bg.lineStyle(4, 0xffffff);
        bg.drawRect(0, 0, miniMapSize, miniMapSize);
        

        final g = new h2d.Graphics(mask);
        g.alpha = 0.6;
        root.x = Main.nativePixelResolution.x 
          - miniMapMargin 
          - miniMapSize;
        root.y = miniMapMargin;

        Main.Global.hooks.update.push((dt) -> {
          root.visible = Main.Global.uiState.hud.enabled
            && !Main.Global.uiState.inventory.enabled;

          final camera = Main.Global.mainCamera; 
          g.x = -camera.x * miniMapScale + miniMapSize / 2;
          g.y = -camera.y * miniMapScale + miniMapSize / 2;

          if (finished) {
            root.remove();
          }

          return !finished;
        });

        g;
      }

      // process each map object
      for (layerId in orderedLayers) {
        final grid = mapData.gridByLayerId.get(layerId);
        final tileGrid = tileGridByLayerId.get(layerId); 

        for (itemId => bounds in grid.itemCache) {
          final objectType = mapData.itemTypeById.get(itemId);
          final objectMeta = editorConfig.objectMetaByType
            .get(objectType);
          final x = bounds[0];
          final y = bounds[2];

          // generate game objects
          switch(objectType) {
            case 'enemySpawnPoint': {
              new EnemySpawner(
                  x,
                  y,
                  5,
                  Main.Global.rootScene,
                  spawnerFindTargetFn);
            } 

            case 'intro_level_boss': {
              final e = new Ai({
                x: x,
                y: y,
                radius: 30,
                sightRange: 150,
                aiType: 'introLevelBoss',
                type: 'ENEMY'
              }, (_) -> Entity.getById('PLAYER'));
              Main.Global.rootScene.addChildAt(e, 0);
            }

            case 'npc_test_dummy': {
              new Ai({
                x: x,
                y: y,
                aiType: 'npcTestDummy',
                type: 'ENEMY',
                radius: 6
              });
            }

            case 'pillar': {
              final spriteKey = objectMeta.spriteKey;
              final spriteData = Reflect.field(
                  spriteSheetData,
                  spriteKey);
              final radius = Std.int(
                  spriteData.sourceSize.w / 2);
              final ref = new MapObstacle({
                id: 'mapObstacle_${itemId}',
                x: x,
                y: y,
                radius: radius,
                avoidanceRadius: radius + 3
              }, objectMeta);
              final initialHealth = 10000;
              ref.stats = EntityStats.create({
                currentHealth: initialHealth,
              });
            }

            case 'player': {
              final cameraPanDuration = 0.9;
              final animDuration = 1.0;
              final cameraStartTime = Main.Global.time;
              final startedAt = Main.Global.time + cameraPanDuration * 0.3;

              function panCameraToPlayer(dt) {
                final progress = (Main.Global.time - cameraStartTime) 
                  / cameraPanDuration;
                final v = Easing.easeOutExpo(progress);
                final initialX = x - 30;
                final dx = x - initialX;
                final initialY = y - 10;
                final dy = y - initialY;

                Camera.follow(
                    Main.Global.mainCamera, {
                      x: initialX + (dx * v),
                      y: initialY + (dy * v),
                    });

                return progress < 1;
              }
              Main.Global.hooks.update
                .push(panCameraToPlayer);

              // materializing animation
              {
                final sb = Main.Global.sb;
                final spriteData = SpriteBatchSystem.getSpriteData(
                    sb.batchManager.spriteSheetData,
                    'player_animation/idle-0--main');

                Main.Global.hooks.render.push((time) -> {
                  final progress = (time - startedAt) / animDuration;
                  final yOffset = spriteData.frame.h * (1 - progress);
                  final spriteRef = sb.emitSprite(
                      x,
                      y + (1 - spriteData.pivot.y) * yOffset,
                      'ui/placeholder'); 
                  final playerTile = sb.batchManager.spriteSheet
                    .sub(spriteData.frame.x
                        ,spriteData.frame.y + yOffset
                        ,spriteData.frame.w
                        ,spriteData.frame.h * progress);
                  playerTile.setCenterRatio(
                      spriteData.pivot.x,
                      spriteData.pivot.y);
                  final b = spriteRef;
                  b.t = playerTile;

                  return progress < 1;
                });

                Main.Global.hooks.render.push((time) -> {
                  final progress = (time - startedAt) / animDuration;
                  final yOffset = spriteData.frame.h * (1 - progress);
                  final spriteRef = sb.emitSprite(
                      x,
                      y + (1 - spriteData.pivot.y) * yOffset,
                      'ui/placeholder'); 
                  final playerTile = sb.batchManager.spriteSheet
                    .sub(spriteData.frame.x
                        ,spriteData.frame.y + yOffset
                        ,spriteData.frame.w
                        ,3);
                  playerTile.dx = -spriteData.pivot.x * spriteData.sourceSize.w;
                  playerTile.dy = -spriteData.pivot.y * spriteData.sourceSize.h * progress;
                  final b = spriteRef;
                  b.t = playerTile;
                  b.r = 999.0;
                  b.g = 999.0;
                  b.b = 999.0;

                  return progress < 1;
                });

                Main.Global.hooks.render.push(function makeSpotlight(_) {
                  final progress = (Main.Global.time - startedAt) 
                    / animDuration;
                  Main.lightingSystem.emitSpotLight(x, y, 3);

                  return progress < 1;
                });
              }

              final makePlayerAfterAnimation = (dt: Float) -> {
                final progress = (Main.Global.time - startedAt) 
                  / animDuration;

                if (progress > 1) {
                  final playerRef = new Player(
                      x,
                      y,
                      Main.Global.rootScene);
                  Camera.follow(
                      Main.Global.mainCamera, 
                      playerRef);

                  return false;
                }

                return true;
              };
              Main.Global.hooks.update
                .push(makePlayerAfterAnimation);
            }

            case 'teleporter': {
              addToTileGrid(tileGrid, x, y, itemId);

              // add traversable areas
              Grid.setItemRect(
                  traversableGrid,
                  x,
                  y,
                  tileGrid.cellSize * 2,
                  tileGrid.cellSize * 3,
                  'teleporter_traversable_rect_${itemId}_1');

              {
                final width = 9;
                final height = 2;
                Grid.setItemRect(
                    traversableGrid,
                    x + (3 * cellSize),
                    y + 2,
                    tileGrid.cellSize * width,
                    tileGrid.cellSize * 2,
                    'teleporter_traversable_rect_${itemId}_2');
              }

              {
                // add teleporter pillars for layering
                final refLeft = new Entity({
                  x: x - 30,
                  y: y + 27,
                  type: 'teleporterPillar'
                });
                refLeft.stats = EntityStats.create({
                  currentHealth: 1.
                });

                refLeft.renderFn = (ref, _) -> {
                  Main.Global.sb.emitSprite(
                      ref.x,
                      ref.y,
                      'ui/teleporter_pillar_left'); 
                };

                final refRight = new Entity({
                  x: refLeft.x + 55,
                  y: refLeft.y,
                  type: 'teleporterPillar'
                });
                refRight.stats = EntityStats.create({
                  currentHealth: 1.
                });

                refRight.renderFn = (ref, _) -> {
                  Main.Global.sb.emitSprite(
                      ref.x,
                      ref.y,
                      'ui/teleporter_pillar_right'); 
                };
              }
            }

            case 'prop_1_1': {
              final ref = new Entity({
                x: x,
                y: y,
                radius: 5,
              });
              ref.renderFn = (ref, time) -> {
                final sprite = Main.Global.sb.emitSprite(
                    ref.x,
                    ref.y,
                    objectMeta.spriteKey);
                if (Main.Global.hoveredEntity.id == ref.id) {
                  Entity.renderOutline(
                      sprite.sortOrder - 1,
                      objectMeta.spriteKey,
                      ref);
                }
              }
              final shatterAnimation = (ref) -> {
                final startedAt = Main.Global.time;
                final duration = 0.5;
                final angle1 = -Math.PI / 2.5 + Utils.rnd(-1, 1, true);
                final angle2 = Math.PI + Utils.rnd(-1, 1, true);
                final angle3 = Math.PI * 2 + Utils.rnd(-1, 1, true);
                final dist = 30;
                Main.Global.hooks.render.push((time) -> {
                  final progress = (time - startedAt) / duration;

                  {
                    final dx = Math.cos(angle1) * dist;
                    final dy = Math.sin(angle1) * dist;
                    final spriteRef = Main.Global.sb.emitSprite(
                        ref.x + dx * progress,
                        ref.y + dy * progress,
                        'ui/prop_1_1_shard_1',
                        (time - startedAt) * 14);
                    spriteRef.alpha = 
                      1 - Easing.easeInQuint(progress);
                  }

                  {
                    final dx = Math.cos(angle2) * dist;
                    final dy = Math.sin(angle2) * dist;
                    final spriteRef = Main.Global.sb.emitSprite(
                        ref.x + dx * progress,
                        ref.y + dy * progress,
                        'ui/prop_1_1_shard_2',
                        (time - startedAt) * 14);
                    spriteRef.alpha = 
                      1 - Easing.easeInQuint(progress);
                  }

                  {
                    final dx = Math.cos(angle3) * dist;
                    final dy = Math.sin(angle3) * dist;
                    final spriteRef = Main.Global.sb.emitSprite(
                        ref.x + dx * progress,
                        ref.y + dy * progress,
                        'ui/prop_1_1_shard_3',
                        (time - startedAt) * 14);
                    spriteRef.alpha = 
                      1 - Easing.easeInQuint(progress);
                  }

                  return progress < 1;
                });

              };
              ref.onDone = shatterAnimation;
              ref.type = 'BREAKABLE_PROP';
              ref.stats = EntityStats.create({
                label: '@prop_1_1',
                currentHealth: 1.,
              });
              Main.Global.rootScene.addChild(ref);
            }

            case 'tile_2': {
              final wallRef = new Entity({
                x: x,
                y: y + 32,
                radius: 8,
                type: 'OBSTACLE'
              });
              final initialHealth = 1000000;
              wallRef.stats = EntityStats.create({
                label: '@prop_1_1',
                currentHealth: 1000000.,
              });
              wallRef.forceMultiplier = 3.0;
              addToTileGrid(tileGrid, x, y, itemId);
              final gridX = Std.int((x - (tileGrid.cellSize / 2)) 
                  / tileGrid.cellSize);
              final gridY = Std.int((y - (tileGrid.cellSize / 2)) 
                  / tileGrid.cellSize);
              final hasTile = (cellData: Grid.GridItems) -> {
                if (cellData == null) {
                  return false;
                }

                for (itemId in cellData) {
                  final oType2 = mapData.itemTypeById.get(itemId);
                  if (oType2 == objectType) {
                    return true;
                  }
                }

                return false;
              };
              wallRef.renderFn = (ref, time) -> {
                final shouldAutoTile = objectMeta.isAutoTile;
                // TODO: we should be able to cache this after 
                // it runs the first  time since we're not 
                // expecting the map layout to dynamically change
                final spriteKey = {
                  if (shouldAutoTile) {
                    final tileValue = AutoTile.getValue(
                        tileGrid, gridX, gridY, 
                        hasTile, 1, objectMeta.autoTileCorner);

                    final sprite = 'ui/${objectType}_${tileValue}';
                    sprite;
                  } else {
                    objectMeta.spriteKey;
                  }
                }
                final oKey = spriteKey.substring(3);
                final wallSprite = Main.Global.sb.emitSprite(
                    x,
                    y,
                    spriteKey);
                wallSprite.sortOrder = wallSprite.y + 32.;

                if (Entity.getComponent(wallRef, 'isObscuring')) {
                  final wallMaskSprite = Main.Global.wmSpriteBatch.emitSprite(
                      x,
                      y,
                      spriteKey);
                }
              };
            }

            case 'treasureChest': {
              final spriteData = SpriteBatchSystem.getSpriteData(
                  Main.Global.sb.batchManager.spriteSheetData,
                  objectMeta.spriteKey);
              final ref = new Entity({
                x: x,
                y: y,
                type: 'INTERACTABLE_PROP',
                stats: EntityStats.create({
                  label: '@treasureChest',
                  currentHealth: 1.,
                }),
              });
              Main.Global.rootScene.addChild(ref);
              final interact = new h2d.Interactive(
                  spriteData.sourceSize.w, 
                  spriteData.sourceSize.h, 
                  ref);
              interact.x = -spriteData.sourceSize.w * spriteData.pivot.x;
              interact.y = -spriteData.sourceSize.h * spriteData.pivot.y;

              interact.onClick = function handleInteract(_) {
                final playerRef = Entity.getById('PLAYER');

                if (!Entity.canInteract(
                    playerRef, ref, playerRef.stats.pickupRadius)) {
                  return;
                }

                Entity.destroy(ref.id); 
                final numItems = Utils.irnd(2, 4);
                final lootPool = [
                  for (type => def in Loot.lootDefinitions) {
                    if (def.category == 'ability') {
                      type;
                    }
                  }
                ];
                for (_ in 0...numItems) {
                  final lootInstance = Loot.createInstance(lootPool);
                  Game.createLootEntity(
                      ref.x + Utils.irnd(5, 10, true), 
                      ref.y + Utils.irnd(5, 10, true),
                      lootInstance);
                }
              }

              Main.Global.hooks.update.push(function handleCursorStyle(_) {
                final playerRef = Entity.getById('PLAYER');
                interact.cursor = Entity.canInteract(
                    playerRef, ref, playerRef.stats.pickupRadius)
                  ? Main.cursorStyle.interact
                  : Main.cursorStyle.target;

                return interact.parent != null;
              });
              
              final timeOffset = Utils.rnd(0, 100);

              ref.renderFn = (ref, t) -> {
                final pulseTime = Math.sin(
                    (Main.Global.time + timeOffset) * 2);
                final sprite = Main.Global.sb.emitSprite(
                    ref.x, ref.y, objectMeta.spriteKey);
                final spotLight = Main.lightingSystem.emitSpotLight(
                    ref.x, 
                    ref.y 
                    + spriteData.pivot.y * spriteData.sourceSize.h
                    - 5,
                    0);
                spotLight.r = 44  / 255;
                spotLight.g = 232 / 255;
                spotLight.b = 245 / 255;
                spotLight.alpha = 0.5 + 0.5 * pulseTime;
                spotLight.scaleX = spriteData.sourceSize.w / 30;
                spotLight.scaleY = spriteData.sourceSize.h / 30;

                if (interact.isOver()) {
                  Entity.renderOutline(
                      sprite.sortOrder - 1,
                      objectMeta.spriteKey,
                      ref);
                }
              }
            }

            case 'npc_quest_provider': {
              function getDialogChoices() {
                return Lambda.fold([
                    'testQuest',
                    'aggressiveBats'
                ], (questName, result: Array<Gui.DialogChoice>) -> {
                  final questState = Main.Global.gameState
                    .questState[questName];

                  if (!questState.active) {
                    result.push({
                      text: Quest.conditionsByName[questName]
                        .defaultState
                        .description,
                      action: {
                        type: 'ACTIVATE_QUEST',
                        data: questName
                      }
                    });
                  }

                  return result;
                }, []);
              }

              final spriteData = SpriteBatchSystem.getSpriteData(
                  Main.Global.sb.batchManager.spriteSheetData,
                  objectMeta.spriteKey);
              final npcRef = new Entity({
                x: x, 
                y: y,
                type: 'NPC',
                stats: EntityStats.create({
                  currentHealth: 1
                }),
                radius: Std.int(spriteData.sourceSize.w / 2)
              });
              Main.Global.rootScene.addChild(npcRef);
              final dialogOffsetY = -spriteData.pivot.y * spriteData.sourceSize.h;

              final state = {
                hovered: false,
                interacting: false,
              };
              final dialogId = 'questNpc';
              final i = new h2d.Interactive(
                  spriteData.sourceSize.w,
                  spriteData.sourceSize.h,
                  npcRef); 
              i.x = -spriteData.pivot.x * spriteData.sourceSize.w;
              i.y = dialogOffsetY;
              i.onClick = (e) -> {
                if (!Main.Global.uiState.dialogBox.enabled) {
                  Main.Global.uiState = Hud.UiStateManager.nextUiState(
                      Hud.UiStateManager.defaultUiState, {
                        dialogBox: {
                          enabled: true
                        }
                      });
                  Gui.DialogBox.create(
                      npcRef.x + i.x,
                      npcRef.y + i.y,
                      () -> {
                        final choices = getDialogChoices();
                        return {
                          characterName: 'Haku, bounty provider',
                          text: choices.length > 0 
                            ? 'Choose a bounty quest:'
                            : 'No more quests available.',
                          choices: choices
                        };
                      },
                      dialogId);
                } else {
                  Main.Global.uiState = Hud.UiStateManager.nextUiState(
                      Hud.UiStateManager.defaultUiState, {
                        dialogBox: {
                          enabled: false
                        }
                      });
                  Gui.DialogBox.destroy(dialogId);
                }
              }

              i.onOver = (e) -> {
                state.hovered = true;
              }

              i.onOut = (e) -> {
                state.hovered = false;
              }

              npcRef.renderFn = (ref, time) -> {
                final sprite = Main.Global.sb.emitSprite(
                    x, y, objectMeta.spriteKey);
                final choices = getDialogChoices();
                final hasNewInfo = choices.length > 0 
                  && !Main.Global.uiState.dialogBox.enabled;

                if (hasNewInfo) {
                  final s = Main.Global.sb.emitSprite(
                      x, 
                      y + dialogOffsetY, 
                      'ui/exclamation_bubble');
                  s.g = 0.8;
                  s.b = 0.2;
                  final light = Main.lightingSystem.sb.emitSprite(
                      x, 
                      y + dialogOffsetY, 
                      'ui/exclamation_bubble');
                  light.r = 255.;
                  light.g = 255.;
                  light.b = 255.;
                  light.scale = 1.2;
                  for (sprite in [s, light]) {
                    sprite.scaleX *= 0.95 + 
                      0.05 * Math.cos(Main.Global.time * 2);
                    sprite.scaleY *= 0.95 
                      + 0.05 * Math.sin(Main.Global.time * 2);
                  }
                }

                if (state.hovered) {
                  Entity.renderOutline(
                      sprite.sortOrder, 
                      objectMeta.spriteKey,
                      npcRef);
                }

                Main.lightingSystem.emitSpotLight(
                    x, y, npcRef.radius * 15);
              };
            }

            // everything else is treated as a tile 
            default: {
              final gridRow = y;

              addToTileGrid(tileGrid, x, y, itemId);
              if (objectMeta.type == 'traversableSpace') {
                Grid.setItemRect(
                    traversableGrid,
                    x, 
                    y, 
                    tileGrid.cellSize,
                    tileGrid.cellSize,
                    itemId);
              } 
            }
          }
        }
      }

      final miniMapPositionsDrawn = [];
      final hasTile = (cellData) -> 
        cellData != null; 

      final refreshMap = (dt) -> {
        final idsRendered = new Map();

        for (layerId in orderedLayers) {
          final tileGrid = tileGridByLayerId.get(layerId);
          final renderTile = (
              gridX: Int, 
              gridY: Int, 
              cellData: Grid.GridItems) -> {
            if (cellData != null) {
              for (itemId in cellData) {
                final objectType = mapData.itemTypeById.get(itemId);
                final objectMeta = editorConfig
                  .objectMetaByType
                  .get(objectType);

                if (!idsRendered.exists(itemId) 
                    && objectMeta.type != 'obstacleWall') {
                  idsRendered.set(itemId, true);

                  final shouldAutoTile = objectMeta.isAutoTile;
                  final spriteKey = {
                    if (shouldAutoTile) {
                      final tileValue = AutoTile.getValue(
                          tileGrid, gridX, gridY, 
                          hasTile, 1, objectMeta.autoTileCorner);

                      final sprite = 'ui/${objectType}_${tileValue}';
                      sprite;
                    } else {
                      objectMeta.spriteKey;
                    }
                  }
                  final pos = truePositionByItemId.get(itemId);

                  final y = {
                    if (objectMeta.alias == 'alien_propulsion_booster') {
                      pos.y + Math.sin(Main.Global.time / 1) * 3;
                    } else {
                      pos.y;
                    }
                  }

                  final tileRef = Main.Global.sb.emitSprite(
                      pos.x,
                      y,
                      spriteKey);
                  // we can safely set all tiles to a sortOrder of 0
                  // since we're adding tiles row-wise which means
                  // they'll all be sorted naturally anyway
                  tileRef.sortOrder = -1;

                  final miniMapPosDrawn = Grid2d.get(
                      miniMapPositionsDrawn, pos.x, pos.y) != null;
                  if (!miniMapPosDrawn) {
                    Grid2d.set(
                        miniMapPositionsDrawn, pos.x, pos.y, true);
                    // predraw minimap
                    switch(objectMeta.type) {
                      case 'traversableSpace': {
                        miniMap.beginFill(0xfffffff);
                        miniMap.drawRect(
                            pos.x * miniMapScale, 
                            y * miniMapScale, 
                            cellSize * miniMapScale, 
                            cellSize * miniMapScale);
                      }
                    }
                  }
                }
              }
            }
          };
          final mc = Main.Global.mainCamera;
          // Pretty large overdraw right now because some 
          // objects that are really large can get clipped too
          // early (ie: teleporter). We can fix this by splitting 
          // large objects into multiple sprites or rendering
          // those objects separately
          final threshold = 200;

          Grid.eachCellInRect(
              tileGrid,
              mc.x, 
              mc.y,
              mc.w + threshold,
              mc.h + threshold,
              renderTile);
        }

#if false
        Debug.traversableAreas(
            traversableGrid,
            spriteSheetTile,
            spriteSheetData,
            tg);
#end

        if (finished) {
          miniMap.remove();
        }

        return !finished;
      }
      Main.Global.hooks.render.push(refreshMap);

    }

    // final levelFile = 'editor-data/dummy_level.eds';
    final levelFile = 'editor-data/level_1.eds';
    SaveState.load(
        levelFile,
        false,
        null,
        (mapData) -> {
          try {
            processMap(levelFile, mapData);
          } catch(err) {
            HaxeUtils.handleError('load level error')(err);
          }

          return;
        }, 
        (err) -> {
          trace('[load level failure]', err.stack);
        });
  }

  // triggers a side-effect to change `canSeeTarget`
  public function lineOfSight(entity, x, y, i) {
    final cellSize = mapRef.cellSize;
    final isClearPath = Grid.isEmptyCell(
        Main.Global.grid.obstacle, x, y);
    final isInSightRange = i * cellSize <= 
      entity.sightRange;

    if (!isClearPath || !isInSightRange) {
      entity.canSeeTarget = false;
      return false;
    }

    entity.canSeeTarget = true;
    return isClearPath;
  }

  public static function createLootEntity(x, y, lootInstance) {
    final startX = x;
    final startY = y;
    final lootRef = new Entity({
      x: startX, 
      y: startY,
      radius: 11,
    }); 
    final endYOffset = Utils.irnd(-5, 5, true);
    final endXOffset = Utils.irnd(-10, 10, true);
    final lootDropAnimation = (dt: Float) -> {
      final duration = 0.3;
      final progress = Math.min(
          1, 
          (Main.Global.time - 
           lootRef.createdAt) / duration);   
      final z = Math.sin(progress * Math.PI) * 10;
      lootRef.x = startX + endXOffset * progress;
      lootRef.y = startY + endYOffset * progress - z;

      return progress < 1;
    };
    Main.Global.hooks.update.push(lootDropAnimation);

    lootRef.type = 'LOOT';
    lootRef.stats = EntityStats.create({
      label: '@LOOT',
      maxHealth: 1,
      currentHealth: 1.,
    });
    // instance-specific data such as the rolled rng values
    // as well as the loot type so we can look it up in the
    // loot definition table
    Entity.setComponent(lootRef, 'lootInstance', 
        lootInstance);
    final radius1 = Utils.rnd(0.5, 1);
    final radius2 = Utils.rnd(0.5, 2);
    final radius3 = Utils.rnd(0.5, 2);
    final timeOffset1 = Utils.rnd(-20, 20) * Utils.rnd(1, 3);
    final timeOffset2 = Utils.rnd(-20, 20) * Utils.rnd(1, 3);
    final timeOffset3 = Utils.rnd(-20, 20) * Utils.rnd(1, 3);
    final xOffset1 = Utils.irnd(-10, 10);
    final xOffset2 = Utils.irnd(-10, 10);
    final xOffset3 = Utils.irnd(-10, 10);
    final yOffset1 = Utils.irnd(-40, 0);
    final yOffset2 = Utils.irnd(-40, 0);
    final yOffset3 = Utils.irnd(-40, 0);

    lootRef.renderFn = (ref, time: Float) -> {
      // drop shadow
      final dropShadow = Main.Global.sb.emitSprite(
          ref.x - ref.radius,
          ref.y + ref.radius - 2,
          'ui/square_white');
      dropShadow.sortOrder = (ref.y / 2) - 1;
      dropShadow.scaleX = ref.radius * 2;
      dropShadow.r = 0;
      dropShadow.g = 0;
      dropShadow.b = 0.2;
      dropShadow.a = 0.2;
      dropShadow.scaleY = ref.radius * 0.5;

      final lootDef = Loot.getDef(
            Entity.getComponent(ref, 'lootInstance').type);
      final spriteKey = lootDef.spriteKey;
      final sprite = Main.Global.sb.emitSprite(
          ref.x,
          ref.y,
          spriteKey);
      sprite.sortOrder = ref.y / 2;

      if (Main.Global.hoveredEntity.id == ref.id) {
        Entity.renderOutline(
            sprite.sortOrder - 0.1,
            spriteKey,
            ref);
      }

      if (lootDef.rarity == Loot.Rarity.Legendary) {
        final lightBeamConfigs: Array<{
          radius: Float,
          x: Float,
          y: Float,
          alpha: Float,
          ?isLightSource: Null<Bool>
        }> = [
          // main beam
          {
            radius: ref.radius * 1.2,
            x: ref.x - ref.radius * 1.2,
            y: ref.y,
            alpha: 0.9 + 0.1 * Math.sin(Main.Global.time * 1.5),
            isLightSource: true
          },
          {
            radius: radius1,
            x: ref.x + xOffset1,
            y: ref.y + yOffset1,
            alpha: Math.sin((Main.Global.time + timeOffset1))
          },
          {
            radius: radius2,
            x: ref.x + xOffset2,
            y: ref.y + yOffset2,
            alpha: Math.sin((Main.Global.time + timeOffset2))
          },
          {
            radius: radius3,
            x: ref.x + xOffset3,
            y: ref.y + yOffset3,
            alpha: Math.sin((Main.Global.time + timeOffset3))
          },
        ];

        for (cfg in lightBeamConfigs) {
          final spriteKey = 'ui/loot_effect_legendary_gradient';
          final sprite = Main.Global.sb.emitSprite(
              cfg.x,
              cfg.y,
              spriteKey);
          final cam = Main.Global.mainCamera;
          final cameraDy = Math.abs(cfg.y - cam.y - 20);
          final alphaFallOff = Math.max(
              0, 1 - Math.pow(cameraDy / cam.h * 2, 3));
          final baseScaleX = cfg.radius * 2;
          final alpha = cfg.alpha * alphaFallOff;
          sprite.scaleY = 1.5;
          sprite.scaleX = baseScaleX;
          sprite.a = alpha;

          if (cfg.isLightSource) {
            final source = Main.lightingSystem.sb.emitSprite(
                cfg.x,
                cfg.y,
                spriteKey);
            source.scaleY = sprite.scaleY;
            source.scaleX = baseScaleX;
            source.alpha = alpha;
          }
        }

        {
          // emit light around object
          final oLight = Main.lightingSystem.sb.emitSprite(
              ref.x,
              ref.y,
              spriteKey);
          oLight.r = 255.;
          oLight.g = 255.;
          oLight.b = 255.;
        }
      }
    };
  }

  public static function makeBackground() {
    final Global = Main.Global;
    final s2d = Global.scene.mainBackground;
    final g = new h2d.Graphics(s2d);
    final scale = Global.resolutionScale;
    final bgBaseColor = 0x1f1f1f;
    
    g.beginFill(bgBaseColor);
    g.drawRect(
        0, 0, 
        s2d.width * scale, 
        s2d.height * scale);

    final p = new hxd.Perlin();
    final width = 1920 + 40;
    final height = 1080 + 40;

    final makeStars = () -> {
      final divisor = 6;
      final xMax = Std.int((width) / scale / divisor);
      final yMax = Std.int((height) / scale / divisor);
      final seed = Utils.irnd(0, 100);
      final starSizes = [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2];
      for (x in 0...xMax) {
        for (y in 0...yMax) {
          final v = p.perlin(seed, x / yMax, y / xMax, 10);
          final color = 0xffffff;
          g.beginFill(color, Math.abs(v) * 1.5);
          g.drawCircle(
              x * divisor + Utils.irnd(-10, 10, true), 
              y * divisor + Utils.irnd(-10, 10, true), 
              Utils.rollValues(starSizes) / 4,
              6);
        }
      }
    }

    final makeNebulaClouds = () -> {
      final colorOptions = [
        0xd10a7e,
        0xe43b44,
        0x1543c1
      ];
      final colorA = Utils.rollValues(colorOptions);
      final colorB = Utils.rollValues(
          Lambda.filter(
            colorOptions,
            (c) -> c != colorA));
      final divisor = 10;
      final xMax = Std.int((width) / scale / divisor);
      final yMax = Std.int((height) / scale / divisor);
      final seed = Utils.irnd(0, 100);
      for (x in 0...xMax) {
        for (y in 0...yMax) {
          final v = p.perlin(seed, x / xMax, y / yMax, 15, 0.25);
          final color = v > 0 ? colorA : colorB;
          g.beginFill(color, Math.abs(v) / 4);
          g.drawCircle(
              x * divisor, 
              y * divisor, 
              10,
              4);
        }
      }
    }

    makeStars();
    makeNebulaClouds();

    return g;
  } 

  public function new(
    s2d: h2d.Scene
  ) {
    super(s2d);

    mapRef = Main.Global.grid.obstacle;
    var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
    var spriteSheetData = Main.Global.sb
      .batchManager.spriteSheetData;

    Main.Global.rootScene = s2d;

    var font: h2d.Font = hxd.res.DefaultFont.get().clone();
    font.resizeTo(24);

    final background = makeBackground();
    final cleanupWhenFinished = (dt) -> {
      if (finished) {
        background.remove();
      }

      return !finished;
    }
    Main.Global.hooks.update
      .push(cleanupWhenFinished);

    newLevel(Main.Global.rootScene);

    Main.Global.hooks.update.push(this.update);
    Main.Global.hooks.render.push(this.render);
    Main.Global.hooks.input.push(function hudUpdate(dt) {
      Hud.update(dt);

      return !finished;
    });
  }

  public function update(dt: Float) {
    final s2d = Main.Global.rootScene;

    if (!Main.Global.isNextFrame) {
      return !finished;
    }

    var isReady = mapRef != null;

    if (!isReady) {
      return !finished;
    }

    // reset before next loop
    for (entityRef in Main.Global.entitiesToRender) {
      Entity.setComponent(entityRef, 'isObscured', false);
      Entity.setComponent(entityRef, 'isObscuring', false);
    }
    Main.Global.entitiesToRender = [];

    Cooldown.update(SoundFx.globalCds, dt);

    var groupIndex = 0;
    for (a in Entity.ALL_BY_ID) {
      // cleanup entity
      if (a.isDone()) {
        final numItemsToDrop = switch(a.type) {
          case 'BREAKABLE_PROP': 
            Utils.rollValues([
                0, 0, 0, 0, 0, 1
            ]);
            case 'ENEMY' 
              if (Entity.getComponent(a, 'aiType') != 'npcTestDummy'): 
                Utils.rollValues([
                    0, 0, 0, 0, 1, 1, 2
                ]);
          default: 0;
        }

        if (numItemsToDrop > 0) {
          for (_ in 0...numItemsToDrop) {
            final lootPool = [
              for (type => def in Loot.lootDefinitions) {
                if (def.category == 'ability') {
                  type;
                }
              }
            ];
            final lootInstance = Loot.createInstance(lootPool);
            Game.createLootEntity(
                a.x + Utils.irnd(5, 10, true), 
                a.y + Utils.irnd(5, 10, true), 
                lootInstance);
          }
        }

        if (a.onDone != null) {
          a.onDone(a);
        }

        Entity.deAlloc(a.id);
        continue;
      }

      groupIndex += 1;
      // reset groupIndex
      if (groupIndex == 60) {
        groupIndex = 0;
      }

      final isDynamic = Entity.getComponent(a, 'isDynamic', false) ||
        switch(a.type) {
          case 
              'ENEMY'
            | 'FRIENDLY_AI'
            | 'PROJECTILE'
            | 'PLAYER': {
              true;
            };

          default: false;
        };

      final isMoving = a.dx != 0 || a.dy != 0;
      final hasTakenDamage = a.stats.damageTaken > 0;
      final isCheckTick = (Main.Global.tickCount + groupIndex) % 
        Entity.getComponent(a, 'neighborCheckInterval') == 0;
      final shouldFindNeighbors = {
        final isRecentlySummoned =  Cooldown.has(
            a.cds, 'recentlySummoned');
        final isActive = isMoving 
          || hasTakenDamage
          || Entity.getComponent(a, 'checkNeighbors', false);

        isDynamic && (
            isRecentlySummoned
            || (isCheckTick && isActive));
      }

      if (shouldFindNeighbors) {
        var neighbors: Array<String> = [];
        final queryThreshold = Entity.getComponent(
            a, 'neighborQueryThreshold');
        var height = a.radius * 2 + queryThreshold;
        var width = height + queryThreshold;
        var dynamicNeighbors = Grid.getItemsInRect(
            Main.Global.grid.dynamicWorld, a.x, a.y, width, height
            );
        var obstacleNeighbors = Grid.getItemsInRect(
            Main.Global.grid.obstacle, a.x, a.y, width, height
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

      // update collision worlds
      switch (a) {
        case 
          { type: 'PLAYER' } 
        | { type: 'ENEMY' } 
        | { type: 'FRIENDLY_AI' }
        | { type: 'BREAKABLE_PROP' }: {
          Grid.setItemRect(
              Main.Global.grid.dynamicWorld,
              a.x,
              a.y,
              a.radius * 2,
              a.radius * 2,
              a.id);
        }
        case 
          { type: 'OBSTACLE' }
        | { type: 'INTERACTABLE_PROP' }
        | { type: 'NPC' }: {
          Grid.setItemRect(
              Main.Global.grid.obstacle,
              a.x,
              a.y,
              a.radius * 2,
              a.radius * 2,
              a.id);
        }
        case { type: 'LOOT' }: {
          Grid.setItemRect(
              Main.Global.grid.lootCol,
              a.x,
              a.y,
              a.radius * 2,
              a.radius * 2,
              a.id);
        }
        default: {}
      }

      Cooldown.update(a.cds, dt);
      // update entity
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

    return !finished;
  }

  public function render(time: Float) {
    for (entityRef in Main.Global.entitiesToRender) {
      entityRef.render(time);
    }

    Main.lightingSystem.globalIlluminate(0.4);
    Hud.render(time);

    return !finished;
  }
}
