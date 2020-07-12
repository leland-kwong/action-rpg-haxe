import h2d.SpriteBatch;
import Game.Cooldown;

typedef SpriteRef = {
  var dx: Float;
  var dy: Float;
  var speed: Float;
  var ?rScaleX: (
      p: SpriteRef, 
      progress: Float) -> Float;
  var ?rScaleY: (
      p: SpriteRef, 
      progress: Float) -> Float;
  var ?sortOrder: Int;
  var lifeTime: Float;
  var createdAt: Float;
  var isNew: Bool;
  var batchElement: BatchElement;
  var spriteKey: String;
};

typedef PartSystem = {
  var particles: Array<SpriteRef>;
  var batch: h2d.SpriteBatch;
  var spriteSheet: h2d.Tile;
  var spriteSheetData: Dynamic;
};

class ParticleSystem {
  static public function init(scene: h2d.Scene) {
    var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
    var system: PartSystem = {
      particles: [],
      spriteSheetData: Utils.loadJsonFile(
          hxd.Res.sprite_sheet_json).frames,
      spriteSheet: spriteSheet,
      batch: new h2d.SpriteBatch(spriteSheet, scene),
    };
    system.batch.hasRotationScale = true;
    return system;
  }

  static public function emit
    (s: PartSystem,
     config: SpriteRef,
     before = false) {

    s.particles.push(config);
    s.batch.add(config.batchElement, before);
  }

  static public function update(
      s: PartSystem, 
      dt: Float) {
    final time = Main.Global.time;
    final particles = s.particles;
    var i = 0;

    while (i < particles.length) {
      final p = particles[i];
      final aliveTime = time - p.createdAt;
      final progress = (aliveTime / p.lifeTime);

      // clear old particles
      if (!p.isNew) {
        particles.splice(i, 1);
        p.batchElement.remove();

        // update particle
      } else {
        i += 1;

        p.isNew = false;
        if (p.rScaleX != null) {
          p.batchElement.scaleX = 
            p.rScaleX(p, progress);
        }
        if (p.rScaleY != null) {
          p.batchElement.scaleY = 
            p.rScaleY(p, progress);
        }
      }
    }

    s.batch.clear();
    // sort by y-position
    particles.sort((a, b) -> {
      var sortA = a.sortOrder == null
        ? a.batchElement.y : a.sortOrder;
      var sortB = b.sortOrder == null
        ? b.batchElement.y : b.sortOrder;

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
  }

  static public function dispose(s: PartSystem) {
    s.batch.remove();
  }
}

// TODO: Rename this to *batch system*
// TODO: Refactor to be simpler and only handle drawing.
// All update logic should be handled separately in their
// own systems. This way we can keep the render batching
// system performant by only doing mutations on sprites
// that actually need it.
// TODO: Refactor to take in a sprite object
// directly so we can do optimizations such as
// reusing sprites each frame if needed.
class ParticlePlayground {
  public var pSystem: PartSystem;

  public function new(scene: h2d.Scene) {
    pSystem = ParticleSystem.init(scene);
  }

  function makeTile(spriteKey: String) {
    var spriteData = Reflect.field(
        pSystem.spriteSheetData,
        spriteKey);

    if (spriteData == null) {
      throw 'invalid spriteKey: `${spriteKey}`';
    }

    var tile = pSystem.spriteSheet.sub(
      spriteData.frame.x,
      spriteData.frame.y,
      spriteData.frame.w,
      spriteData.frame.h
    );

    tile.setCenterRatio(
        spriteData.pivot.x,
        spriteData.pivot.y);

    return tile;
  }

  public function emitSprite(
    x1: Float,
    y1: Float,
    x2: Float,
    y2: Float,
    speed: Float,
    spriteKey: String,
    lifeTime = 0.0,
    ?rScaleX,
    ?rScaleY
  ) {
    final angle = Math.atan2(
        y2 - y1,
        x2 - x1);
    final g = new BatchElement(makeTile(spriteKey));
    g.rotation = angle;
    g.x = x1;
    g.y = y1;
    final spriteRef: SpriteRef = {
      dx: Math.cos(angle),
      dy: Math.sin(angle),
      lifeTime: lifeTime,
      speed: speed,
      createdAt: Main.Global.time,
      batchElement: g,
      rScaleX: rScaleX,
      rScaleY: rScaleY,
      // guarantees it lasts at least 1 frame
      isNew: true,
      spriteKey: spriteKey
    }

    ParticleSystem.emit(pSystem, spriteRef);

    return spriteRef;
  }

  public function update(dt) {
    ParticleSystem.update(pSystem, dt);
  }
}
