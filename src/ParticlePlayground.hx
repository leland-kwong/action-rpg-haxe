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
  var ?rColor: (p: Particle, progress: Float) -> Void;
  var ?sortOrder: Int;
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
  static public function init(scene: h2d.Scene) {
    var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
    var system: PartSystem = {
      particles: [],
      spriteSheetData: Utils.loadJsonFile(hxd.Res.sprite_sheet_json).frames,
      spriteSheet: spriteSheet,
      batch: new h2d.SpriteBatch(spriteSheet, scene),
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
          if (p.rColor != null) {
            p.rColor(p, progress);
          }
        }
      }
    }

    s.batch.clear();
    // sort by y-position
    particles.sort((a, b) -> {
      var sortA = a.sortOrder == null 
        ? a.y : a.sortOrder;
      var sortB = b.sortOrder == null 
        ? b.y : b.sortOrder;

      if (sortA < sortB) {
        return 1;
      }

      if (sortA > sortB) {
        return -1;
      }

      return 0;
    });

    for (p in particles) {
      s.batch.add(p.batchElement, true);
    }

    s.time += dt;
  }

  static public function dispose(s: PartSystem) {
      s.batch.remove();
  }
}

class ParticlePlayground {
  var cds = new Cooldown();
  var spriteList = [];
  var time = 0.0;
  var bulletEnemyLarge: h2d.Tile;
  var tileWithGlow: h2d.Tile;
  var circleTile: h2d.Tile;
  var spriteTypes: Map<String, h2d.Tile> = new Map();
  public var pSystem: PartSystem;

  public function new(scene: h2d.Scene) {
    pSystem = ParticleSystem.init(scene);
  }

  function makeTile(spriteKey: String) {
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
  public function emitSprite(
    x1: Float,
    y1: Float,
    x2: Float,
    y2: Float,
    speed: Float,
    spriteKey: String,
    lifeTime = 1.0,
    rScaleX = null,
    rScaleY = null,
    rAlpha = null,
    rColor = null
  ) {
    var sprite: Particle = null;
    {
      var angle = Math.atan2(
        y2 - y1,
        x2 - x1
      );
      var g = new BatchElement(makeTile(spriteKey));
      g.rotation = angle;
      g.scale = Main.Global.pixelScale;
      sprite = {
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
        rScaleY: rScaleY,
        rColor: rColor,
      };
      ParticleSystem.emit(pSystem, sprite);
      spriteList.push(sprite);
    }
    return sprite;
  }

  public function removeSprite(spriteRef: Particle) {
    spriteRef.lifeTime = 0.0;
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
