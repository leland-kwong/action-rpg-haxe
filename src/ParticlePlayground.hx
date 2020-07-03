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
  var ?rScaleX: (p: Particle, progress: Float) -> Float;
  var ?rScaleY: (p: Particle, progress: Float) -> Float;
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
      batch: new h2d.SpriteBatch(spriteSheet, Main.Global.particleScene),
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
          if (p.rScaleX != null) {
            p.batchElement.scaleX = p.rScaleX(p, progress);
          }
          if (p.rScaleY != null) {
            p.batchElement.scaleY = p.rScaleY(p, progress);
          }
        }
      }
    }

    s.batch.clear();
    // sort by y-position
    particles.sort((a, b) -> {
      var ay = a.y;
      var by = b.y;

      if (ay > by) {
        return 1;
      }

      if (ay < by) {
        return -1;
      }

      return 0;
    });

    for (p in particles) {
      s.batch.add(p.batchElement, true);
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
  public var pSystem: PartSystem;

  public function new() {
    pSystem = ParticleSystem.init();
  }

  function makeSprite(spriteKey: String) {
    var spriteData = Reflect.field(pSystem.spriteSheetData, spriteKey);

    if (spriteData == null) {
      throw 'invalid spriteKey: `${spriteKey}`';
    }

    var tile = pSystem.spriteSheet.sub(
      spriteData.frame.x,
      spriteData.frame.y,
      spriteData.frame.w,
      spriteData.frame.h
    );

    tile.setCenterRatio(spriteData.pivot.x, spriteData.pivot.y);

    return tile;
  }

  // TODO add support for animation
  public function emitProjectileGraphics(
    x1: Float,
    y1: Float,
    x2: Float,
    y2: Float,
    speed: Float,
    spriteKey: String,
    lifeTime = 9999.0,
    rScaleX = null,
    rScaleY = null,
    rAlpha = null
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
        lifeTime: lifeTime,
        speed: speed,
        createdAt: time,
        batchElement: g,
        rAlpha: rAlpha,
        rScaleX: rScaleX,
        rScaleY: rScaleY
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

    ParticleSystem.update(pSystem, dt);
  }
}
