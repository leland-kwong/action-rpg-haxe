import h2d.SpriteBatch;

typedef EffectCallback = (p: SpriteRef) -> Void;

typedef SpriteData = {
	frame: {x:Int,y:Int,w:Int,h:Int},
	rotated: Bool,
	trimmed: Bool,
	spriteSourceSize: {x:Int,y:Int,w:Int,h:Int},
	sourceSize: {w:Int,h:Int},
	pivot: {x:Float,y:Float}
};

typedef SpriteSheetData = {
  frames: Dynamic
};


typedef SpriteRef = {
  var sortOrder: Float;
  var batchElement: BatchElement;
};

typedef BatchManagerRef = {
  var particles: Array<SpriteRef>;
  var batch: h2d.SpriteBatch;
  var spriteSheet: h2d.Tile;
  var spriteSheetData: SpriteSheetData;
};

class BatchManager {
  static public function init(
      scene: h2d.Scene,
      spriteSheetPng: hxd.res.Image,
      spriteSheetJson: hxd.res.Resource) {
    var spriteSheet = spriteSheetPng.toTile();
    var system: BatchManagerRef = {
      particles: [],
      spriteSheetData: Utils.loadJsonFile(
          spriteSheetJson),
      spriteSheet: spriteSheet,
      batch: new h2d.SpriteBatch(spriteSheet, scene),
    };
    system.batch.hasRotationScale = true;
    return system;
  }

  static public function emit(
      s: BatchManagerRef,
      config: SpriteRef) {

    if (Main.Global.mainPhase 
        != Main.MainPhase.Render) {
      trace('rendering must be done inside the render phase');
    }

    s.particles.push(config);
  }

  static public function update(
      s: BatchManagerRef, 
      dt: Float) {

    // reset for next cycle
    s.batch.clear();
    s.particles = [];
  }

  static public function render(
      s: BatchManagerRef, 
      time: Float) {

    // sort by y-position or custom sort value
    // draw order is lowest -> highest

    s.particles.sort((a, b) -> {
      var sortA = a.sortOrder;
      var sortB = b.sortOrder;

      if (sortA < sortB) {
        return -1;
      }

      if (sortA > sortB) {
        return 1;
      }

      return 0;
    });

    for (p in s.particles) {
      s.batch.add(p.batchElement);
    }
  }
}

class SpriteBatchSystem {
  public static final instances: Array<BatchManagerRef> = [];
  public static final tileCache: Map<String, h2d.Tile> = new Map();
  public var batchManager: BatchManagerRef;

  public function new(
      scene: h2d.Scene,
      spriteSheetPng: hxd.res.Image,
      spriteSheetJson: hxd.res.Resource) {
    batchManager = BatchManager.init(
        scene,
        spriteSheetPng,
        spriteSheetJson);
    instances.push(batchManager);
  }

  public static function makeTile(
      spriteSheetTile: h2d.Tile,
      spriteSheetData: SpriteSheetData, 
      spriteKey: String,
      useCache = true) {

    final fromCache = useCache 
      ? tileCache.get(spriteKey)
      : null;

    if (fromCache != null) {
      return fromCache;
    }

    final spriteData = getSpriteData(
        spriteSheetData, spriteKey);

    // TODO: Consider using a placeholder sprite (pink box?) instead
    // of crashing so the game can gracefully continue even though
    // the graphic will not render properly.
    if (spriteData == null) {
      throw 'invalid spriteKey: `${spriteKey}`';
    }

    final tile = spriteSheetTile.sub(
        spriteData.frame.x,
        spriteData.frame.y,
        spriteData.frame.w,
        spriteData.frame.h);

    final pivot = Reflect.field(spriteData, 'pivot');

    if (pivot != null) {
      tile.setCenterRatio(
          spriteData.pivot.x,
          spriteData.pivot.y);

      // this accounts for pivots that generate fractional
      // values which can happen when a sprite's size is
      // an odd number
      tile.dx = Math.round(tile.dx);
      tile.dy = Math.round(tile.dy);
    }

    if (useCache) {
      tileCache.set(spriteKey, tile);
    }

    return tile;
  }

  public function emitSprite(
    x: Float,
    y: Float,
    spriteKey: String,
    ?angle: Float,
    // a callback for running side effects
    // to modify the sprite before rendering
    ?effectCallback: EffectCallback) {

    final g = new BatchElement(
        makeTile(
          this.batchManager.spriteSheet,
          this.batchManager.spriteSheetData, 
          spriteKey));
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

  public static function getSpriteData(
      spriteSheetData: SpriteSheetData,
      spriteKey): SpriteData {

    return Reflect.field(
        spriteSheetData.frames, 
        spriteKey);
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
