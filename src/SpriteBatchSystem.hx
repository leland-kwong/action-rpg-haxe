import h2d.SpriteBatch;
import Game.Cooldown;

private typedef EffectCallback = (p: SpriteRef) -> Void;

typedef SpriteRef = {
  var ?sortOrder: Float;
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

  static public function render(
      s: PartSystem, 
      time: Float) {
    final particles = s.particles;

    // sort by y-position or custom sort value
    // draw order is lowest -> highest
    particles.sort((a, b) -> {
      var sortA = a.sortOrder;
      var sortB = b.sortOrder;

      if (sortA < sortB) {
        return 1;
      }

      if (sortA > sortB) {
        return -1;
      }

      return 0;
    });

    s.batch.clear();
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
        s.batch.add(p.batchElement, true);
      }
    }
  }

}

// TODO: Rename this to *batch system*
// TODO: Refactor to take in a sprite object
// directly so we can do optimizations such as
// reusing sprites each frame if needed.
class SpriteBatchSystem {
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
    x: Float,
    y: Float,
    spriteKey: String,
    ?angle: Float,
    ?effectCallback: EffectCallback) {

    // TODO makeSpriteRef a class
    // that extends from `BatchElement` 
    // so we don't have to create an extra
    // anonymous structure just for a few props
    final g = new BatchElement(makeTile(spriteKey));
    if (angle != null) {
      g.rotation = angle;
    }
    g.x = x;
    g.y = y;
    final spriteRef: SpriteRef = {
      batchElement: g,
      sortOrder: y,
      // guarantees it lasts at least 1 frame
      isOld: false,
    }
    if (effectCallback != null) {
      effectCallback(spriteRef);
    }

    ParticleSystem.emit(pSystem, spriteRef);

    return spriteRef;
  }

  public function render(time: Float) {
    ParticleSystem.render(pSystem, time);
  }
}
