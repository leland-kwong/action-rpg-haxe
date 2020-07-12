import h2d.SpriteBatch;
import Game.Cooldown;

private typedef EffectCallback = (p: SpriteRef) -> Void;

typedef SpriteRef = {
  var ?sortOrder: Float;
  var batchElement: BatchElement;
};

typedef BatchManagerRef = {
  var particles: Array<SpriteRef>;
  var batch: h2d.SpriteBatch;
  var spriteSheet: h2d.Tile;
  var spriteSheetData: Dynamic;
};

class BatchManager {
  static public function init(scene: h2d.Scene) {
    var spriteSheet = hxd.Res.sprite_sheet_png.toTile();
    var system: BatchManagerRef = {
      particles: [],
      spriteSheetData: Utils.loadJsonFile(
          hxd.Res.sprite_sheet_json).frames,
      spriteSheet: spriteSheet,
      batch: new h2d.SpriteBatch(spriteSheet, scene),
    };
    system.batch.hasRotationScale = true;
    return system;
  }

  static public function emit(
      s: BatchManagerRef,
      config: SpriteRef) {

    s.particles.push(config);
  }

  static public function update(
      s: BatchManagerRef, 
      dt: Float) {

    // reset for next cycle
    s.particles = [];
    s.batch.clear();
  }

  static public function render(
      s: BatchManagerRef, 
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

    for (p in particles) {
      s.batch.add(p.batchElement, true);
    }
  }
}

class SpriteBatchSystem {
  public static final instances: Array<BatchManagerRef> = [];
  public var batchManager: BatchManagerRef;

  public function new(scene: h2d.Scene) {
    batchManager = BatchManager.init(scene);
    instances.push(batchManager);
  }

  function makeTile(spriteKey: String) {
    var spriteData = Reflect.field(
        batchManager.spriteSheetData,
        spriteKey);

    if (spriteData == null) {
      throw 'invalid spriteKey: `${spriteKey}`';
    }

    var tile = batchManager.spriteSheet.sub(
        spriteData.frame.x,
        spriteData.frame.y,
        spriteData.frame.w,
        spriteData.frame.h);

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
    }
    if (effectCallback != null) {
      effectCallback(spriteRef);
    }

    BatchManager.emit(batchManager, spriteRef);

    return spriteRef;
  }

  public static function updateAll(dt: Float) {
    for (bm in instances) {
      BatchManager.update(bm, dt);
    }
  }
  
  public static function renderAll(time: Float) {
    for (bm in instances) {
      BatchManager.render(bm, time);
    }
  }
}
