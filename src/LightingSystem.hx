import h3d.mat.Data;
import h3d.mat.Texture;
import h3d.mat.DepthBuffer;

class LightingSystem {
  var renderTargetScene: h2d.Scene; 
  var renderScene: h2d.Scene;
  var renderTarget: h3d.mat.Texture;
  public var sb: SpriteBatchSystem;

  public function new(engine) {
    renderTargetScene = new h2d.Scene();
    renderScene = new h2d.Scene();
    for (s2d in [renderScene, renderTargetScene]) {
      s2d.scaleMode = ScaleMode.Zoom(Main.Global.resolutionScale);
    }

    final ambientShadowLayer = {
      final res = Main.nativePixelResolution;
      final scale = Main.Global.resolutionScale;
      final bmp = new h2d.Bitmap(
          h2d.Tile.fromColor(
            0x000000,
            Std.int(res.x / scale),
            Std.int(res.y / scale)),
          renderTargetScene);
      bmp;
    }

    renderTarget = {
      final gameScale = Main.Global.resolutionScale;
      final width = Std.int(
          Main.nativePixelResolution.x / gameScale);
      final height = Std.int(
          Main.nativePixelResolution.y / gameScale);
      final rt = new Texture( width, height, [ Target ] );
      rt.filter = Nearest;
      rt.depthBuffer = new DepthBuffer( width, height );

      final textureBitmap = {
        final bmp = new h2d.Bitmap(
            h2d.Tile.fromTexture(rt),
            renderScene);
        bmp.blendMode = h2d.BlendMode.Multiply;
        bmp;
      }
      rt;
    }

    sb = {
      final sb = new SpriteBatchSystem(
        renderTargetScene,
        hxd.Res.sprite_sheet_png,
        hxd.Res.sprite_sheet_json);
      final batch = sb.batchManager.batch;
      batch.filter = new h2d.filter.Blur(2);
      batch.blendMode = h2d.BlendMode.Add;
      sb;
    }

    Main.Global.hooks.update.push(function syncToCamera(_) {
      final cam = Main.Global.mainCamera;
      final cam_center_x = -cam.x 
        + Math.fround(Main.Global.rootScene.width / 2);
      final cam_center_y = -cam.y 
        + Math.fround(Main.Global.rootScene.height / 2);

      sb.setTranslate(
          cam_center_x,
          cam_center_y);

      return true;
    });
  }

  public function globalIlluminate(a = 0.2) {
    final cam = Main.Global.mainCamera;
    final s = sb.emitSprite(
        cam.x - cam.w / 2,
        cam.y - cam.h / 2,
        'ui/square_white');
    s.alpha = a;
    s.scaleX = cam.w;
    s.scaleY = cam.h;

    return true;
  }

  public function emitSpotLight(
      x: Float, y: Float, 
      scaleX: Float, ?scaleY: Float) {
    final sprite = sb.emitSprite(
        x, y, 
        'ui/spotlight');
    sprite.scaleX = 2 * scaleX / 100;

    final sy = scaleY == null ? scaleX : scaleY;
    sprite.scaleY = 2 * sy / 100;

    return sprite;
  }

  public function render(e: h3d.Engine) {
    e.pushTarget(renderTarget);
    e.clear(0);
    renderTargetScene.render(e);
    e.popTarget();

    renderScene.render(e);
  }
}

