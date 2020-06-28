import haxe.Json;
import h2d.SpriteBatch;
import Game.Cooldown;

typedef Particle = {
  var dx: Float;
  var dy: Float;
  var x: Float;
  var y: Float;
  var speed: Float;
  var ?rAlpha: (p: Particle, progress: Float) -> Float;
  var ?rScale: (p: Particle, progress: Float) -> Float;
  var lifeTime: Float;
  var createdAt: Float;
  var batchElement: BatchElement;
};

typedef PartSystem = {
  var particles: Array<Particle>;
  var batch: h2d.SpriteBatch;
  var spriteSheet: h2d.Tile;
  var spriteSheetData: Dynamic;
  var time: Float;
};

class ParticleSystem {
  static public function init() {
    var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
    var system: PartSystem = {
      particles: [],
      spriteSheetData: Utils.loadJsonFile(hxd.Res.sprite_sheet_json).frames,
      spriteSheet: spriteSheet,
      batch: new h2d.SpriteBatch(spriteSheet, Main.Global.rootScene),
      time: 0.0
    };
    system.batch.hasRotationScale = true;
    return system;
  }

  static public function emit(s: PartSystem, config: Particle, before = false) {
    s.particles.push(config);
    config.batchElement.x = config.x;
    config.batchElement.y = config.y;
    s.batch.add(config.batchElement, before);
  }

  static public function update(s: PartSystem, dt: Float) {
    s.time += dt;
				var time = s.time;
				var particles = s.particles;

    {
      var i = 0;
      while (i < particles.length) {
        var p = particles[i];
        var aliveTime = time - p.createdAt;
        // clear old particles
        if (aliveTime >= p.lifeTime) {
          particles.splice(i, 1);
          p.batchElement.remove();

        // update particle
        } else {
          i += 1;

          p.x += p.dx * p.speed * dt;
          p.y += p.dy * p.speed * dt;
          var aliveTime = time - p.createdAt;
          var progress = (aliveTime / p.lifeTime);
          p.batchElement.x = p.x;
          p.batchElement.y = p.y;
          if (p.rAlpha != null) {
            p.batchElement.alpha = p.rAlpha(p, progress);
          }
          if (p.rScale != null) {
            p.batchElement.scale = p.rScale(p, progress);
          }
        }
      }
    }
  }

		static public function dispose(s: PartSystem) {
				s.batch.remove();
		}
}

class ParticlePlayground {
  var cds = new Cooldown();
  var projectileList = [];
  var time = 0.0;
  var bulletEnemyLarge: h2d.Tile;
  var tileWithGlow: h2d.Tile;
  var circleTile: h2d.Tile;
  var spriteTypes: Map<String, h2d.Tile> = new Map();
  var pSystem: PartSystem;

  public function new() {
    pSystem = ParticleSystem.init();

    var spriteBulletEnemyLargeData = pSystem.spriteSheetData.bullet_enemy_large;
    spriteTypes['bulletEnemyLarge'] = pSystem.spriteSheet.sub(
      spriteBulletEnemyLargeData.frame.x,
      spriteBulletEnemyLargeData.frame.y,
      spriteBulletEnemyLargeData.frame.w,
      spriteBulletEnemyLargeData.frame.h
    ).center();
    var spriteSquareWithGlowData = pSystem.spriteSheetData.square_white_glow;
    spriteTypes['playerBullet'] = pSystem.spriteSheet.sub(
      spriteSquareWithGlowData.frame.x,
      spriteSquareWithGlowData.frame.y,
      spriteSquareWithGlowData.frame.w,
      spriteSquareWithGlowData.frame.h
    ).center();
  }

  function makeSprite(spriteKey: String) {
    var spriteData = Reflect.field(pSystem.spriteSheetData, spriteKey);

    if (spriteData == null) {
      throw 'invalid spriteKey: `${spriteKey}`';
    }

    return pSystem.spriteSheet.sub(
      spriteData.frame.x,
      spriteData.frame.y,
      spriteData.frame.w,
      spriteData.frame.h
    ).center();
  }

  public function emitProjectileGraphics(
    x1: Float,
    y1: Float,
    x2: Float,
    y2: Float,
    speed: Float,
    spriteKey: String
  ) {
    var projectile: Particle = null;
    {
      var angle = Math.atan2(
        y2 - y1,
        x2 - x1
      );
      var g = new BatchElement(makeSprite(spriteKey));
      g.rotation = angle;
      g.scale = 4;
      projectile = {
        dx: Math.cos(angle),
        dy: Math.sin(angle),
        x: x1,
        y: y1,
        lifeTime: 9999.0,
        speed: speed,
        createdAt: time,
        batchElement: g,
      };
      ParticleSystem.emit(pSystem, projectile);
      projectileList.push(projectile);
    }
    return projectile;
  }

  public function removeProjectile(projectileRef: Particle) {
    projectileRef.lifeTime = 0.0;
  }

  public function dispose() {
    ParticleSystem.dispose(pSystem);
  }

  public function update(dt) {
    time += dt;
    cds.update(dt);

    /**
      Commented code was for projectil particle trail effect. This was originally
      for just the player's bullet, so we'll need to generalize it for more customizable
      functionality.
    **/

    // var shouldEmitParticle = !cds.has('emitParticle');
    // if (shouldEmitParticle) {
    //   var projectileSpeed = 1000;
    //   var emissionRate =  1 / projectileSpeed * 30;
    //   cds.set('emitParticle', emissionRate);
    // }

    // var i = 0;
    // function pAlpha(p, progress: Float) {
    //   return 1 - progress;
    // }

    // function pScale(p, progress: Float) {
    //   return (1 - (progress / 2)) / 2;
    // }

    // function projectileHitAlpha(p, progress: Float) {
    //   return 1 - progress;
    // }

    // while (i < projectileList.length) {
    //   var p = projectileList[i];
    //   // cleanup projectile
    //   if (time - p.createdAt >= p.lifeTime) {
    //     projectileList.splice(i, 1);

    //     for (_ in 0...3) {
    //       var batchElement = new BatchElement(circleTile);
    //       var angle = Math.atan2(p.dy, p.dx)
    //         + Math.PI
    //         + (Math.PI / 8 * Utils.irnd(-3, 3, true));

    //       batchElement.scaleX = 1.2;
    //       batchElement.scaleY = 0.4;
    //       batchElement.rotation = angle;
		// 								batchElement.r = 0.2;
		// 								batchElement.g = 0.8;

    //       var particleConfig = {
    //         dx: Math.cos(angle),
    //         dy: Math.sin(angle),
    //         x: p.x,
    //         y: p.y,
    //         speed: 400.0,
    //         lifeTime: 0.15,
    //         rAlpha: projectileHitAlpha,
    //         createdAt: time,
    //         batchElement: batchElement,
    //       };
    //       ParticleSystem.emit(pSystem, particleConfig);
    //     }
    //   }
    //   else {
    //     i += 1;

    //     if (shouldEmitParticle) {
    //       var rootScene = Main.Global.rootScene;
    //       var count = 3;
    //       var startAngle = Math.atan2(
    //         rootScene.mouseY - 0,
    //         rootScene.mouseX - 0
    //       );
    //       var angleDiff = Math.PI / 4;
    //       for (_ in 0...count) {
    //         var batchElement = new BatchElement(tile);
    //         var angle = startAngle + Utils.rnd(-angleDiff, angleDiff, true);
    //         var dx = Math.cos(angle);
    //         var dy = Math.sin(angle);
    //         var particleConfig = {
    //           dx: 0.0,
    //           dy: 0.0,
    //           x: p.x + dx * Utils.irnd(-8, 8, true),
    //           y: p.y + dy * Utils.irnd(-8, 8, true),
    //           speed: (p.speed * 0.1),
    //           lifeTime: 0.10,
    //           createdAt: time,
    //           rAlpha: pAlpha,
    //           rScale: pScale,
    //           batchElement: batchElement,
    //         };
    //         if (Utils.irnd(0, 1) == 0) {
    //           batchElement.r = 0.1;
    //           batchElement.g = 0.75;
    //         }
    //         else {
    //           batchElement.r = 0.1;
    //           batchElement.g = 0.55;
    //         }
    //         ParticleSystem.emit(pSystem, particleConfig, true);
    //       }
    //     }
    //   }
    // }

    ParticleSystem.update(pSystem, dt);
  }
}
