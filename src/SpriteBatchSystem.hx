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

class SpriteRef extends BatchElement {
  public var sortOrder: Float;
  public var createdAt: Float;
  public var done = true;
  public var effectCallback: EffectCallback;
  public var state: Dynamic;
}

typedef BatchSortFn = (
    a: SpriteRef, b: SpriteRef) -> Int;

typedef BatchManagerRef = {
  var particles: Array<SpriteRef>;
  var nextParticles: Array<SpriteRef>;
  final batch: h2d.SpriteBatch;
  final spriteSheet: h2d.Tile;
  final spriteSheetData: SpriteSheetData;
  final sortFunction: Null<BatchSortFn>;
};

class BatchManager {
  static public function init(
      parent: h2d.Object,
      spriteSheetPng: hxd.res.Image,
      spriteSheetJson: hxd.res.Resource,
      sortFunction) {
    var spriteSheet = spriteSheetPng.toTile();
    var system: BatchManagerRef = {
      particles: [],
      nextParticles: [],
      spriteSheetData: Utils.loadJsonFile(
          spriteSheetJson),
      spriteSheet: spriteSheet,
      batch: new h2d.SpriteBatch(spriteSheet, parent),
      sortFunction: sortFunction
    };
    system.batch.hasRotationScale = true;
    return system;
  }

  static public function emit(
      s: BatchManagerRef,
      sprite: SpriteRef) {

    if (Main.Global.mainPhase 
        != Main.MainPhase.Render) {
      trace('rendering must be done inside the render phase');
    }

    s.particles.push(sprite);
  }

  static public function update(
      s: BatchManagerRef, 
      dt: Float) {

    // reset for next cycle
    s.batch.clear();
    s.particles = s.nextParticles;
    s.nextParticles = [];
  }

  static public function render(
      s: BatchManagerRef, 
      time: Float) {

    for (p in s.particles) {
      if (p.effectCallback != null) {
        p.effectCallback(p);
      }
    }

    if (s.sortFunction != null) {
      s.particles.sort(s.sortFunction);
    }

    for (p in s.particles) {
      s.batch.add(p);
      if (!p.done) {
        s.nextParticles.push(p);
      }
    }
  }
}

typedef SpriteInfo = {
  final hasShadow: Bool;
  final hasLightSource: Bool;
}

typedef EmitOptions = {
  final renderShadow: Bool;
  final renderLightSource: Bool;
}

class SpriteBatchSystem {
  static final spriteInfoCacheBySpriteKey 
    = new Map<String, SpriteInfo>();
  public static final instances: Array<BatchManagerRef> = [];
  public static final tileCache: Map<String, h2d.Tile> = new Map();
  public static final ySort: BatchSortFn = (a, b) -> {
    final sortA = a.sortOrder;
    final sortB = b.sortOrder;

    if (sortA < sortB) {
      return -1;
    }

    if (sortA > sortB) {
      return 1;
    }

    return 0;
  }

  public var batchManager: BatchManagerRef;
  var translate = {
    x: 0.,
    y: 0.
  };

  public function new(
      parent: h2d.Object,
      spriteSheetPng: hxd.res.Image,
      spriteSheetJson: hxd.res.Resource,
      ?sortFunction: BatchSortFn) {

    batchManager = BatchManager.init(
        parent,
        spriteSheetPng,
        spriteSheetJson,
        sortFunction);

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

  public function setTranslate(x, y) {
    translate.x = x;
    translate.y = y;
  }

  public static final emitOptionsNoShadow: EmitOptions = {
    renderShadow: false,
    renderLightSource: false
  }

  static final emitDefaultOptions: EmitOptions = {
    renderShadow: true,
    renderLightSource: true
  }

  public function emitSprite(
    x: Float,
    y: Float,
    spriteKey: String,
    ?angle: Float,
    // a callback for running side effects
    // to modify the sprite before rendering
    ?effectCallback: EffectCallback,
    ?inputOptions: EmitOptions): SpriteRef {

    final options = inputOptions == null
      ? emitDefaultOptions
      : inputOptions;
    final bm = this.batchManager;
    final spriteInfo: SpriteInfo = {
      final info = spriteInfoCacheBySpriteKey.get(
          spriteKey);

      if (info == null) {
        final newInfo: SpriteInfo = {
          hasShadow: getSpriteData(
            bm.spriteSheetData, 
            '${spriteKey}--shadow') != null,
          hasLightSource: getSpriteData(
            bm.spriteSheetData, 
            '${spriteKey}--light_source') != null,
        };
        spriteInfoCacheBySpriteKey.set(spriteKey, newInfo);
        newInfo;
      } else {
        info;
      }
    }

    final spriteRef = new SpriteRef(
        makeTile(
          bm.spriteSheet,
          bm.spriteSheetData, 
          spriteKey));
    if (angle != null) {
      spriteRef.rotation = angle;
    }

    spriteRef.createdAt = Main.Global.time;
    spriteRef.effectCallback = effectCallback;
    spriteRef.x = x + translate.x;
    spriteRef.y = y + translate.y;
    spriteRef.sortOrder = y;

    BatchManager.emit(batchManager, spriteRef);

    if (spriteInfo.hasShadow 
        && options.renderShadow) {
      final shadowKey = '${spriteKey}--shadow';
      final shadow = emitSprite(
          x, y, shadowKey);
      shadow.sortOrder = 0;
    }

    if (spriteInfo.hasLightSource 
        && options.renderLightSource) {
      final lightSourceKey = '${spriteKey}--light_source';
      Main.lightingSystem.sb.emitSprite(
          x, y, lightSourceKey);
    }

    return spriteRef;
  }

  public static function getSpriteData(
      spriteSheetData: SpriteSheetData,
      spriteKey): SpriteData {

      final data = Reflect.field(
        spriteSheetData.frames, 
        spriteKey);

      if (data != null) {
        return data;
      }

      final altData = Reflect.field(
          spriteSheetData.frames, 
          '${spriteKey}--main');

      return altData;
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
