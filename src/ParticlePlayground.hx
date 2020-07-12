import h2d.SpriteBatch;
import Game.Cooldown;

typedef SpriteRef = {
  var dx: Float;
  var dy: Float;
  var ?rScaleX: (p: SpriteRef) -> Float;
  var ?rScaleY: (p: SpriteRef) -> Float;
  var ?sortOrder: Int;
  var isOld: Bool;
  var batchElement: BatchElement;
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
    final particles = s.particles;
    var i = 0;

    while (i < particles.length) {
      final p = particles[i];

      // clear old particles
      if (p.isOld) {
        particles.splice(i, 1);
        p.batchElement.remove();

        // update particle
      } else {
        i += 1;

        p.isOld = true;
        if (p.rScaleX != null) {
          p.batchElement.scaleX = 
            p.rScaleX(p);
        }
        if (p.rScaleY != null) {
          p.batchElement.scaleY = 
            p.rScaleY(p);
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
    spriteKey: String,
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
      batchElement: g,
      rScaleX: rScaleX,
      rScaleY: rScaleY,
      // guarantees it lasts at least 1 frame
      isOld: false,
    }

    ParticleSystem.emit(pSystem, spriteRef);

    return spriteRef;
  }

  public function update(dt) {
    ParticleSystem.update(pSystem, dt);
  }
}
