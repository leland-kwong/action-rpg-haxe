import h3d.mat.Data;
import h3d.mat.Texture;
import h3d.mat.DepthBuffer;

class RenderTargetTest {
  var renderTargetScene: h2d.Scene; 
  var renderScene: h2d.Scene;
  var renderTarget: h3d.mat.Texture;
  public var lightingSb: SpriteBatchSystem;

  public function new(engine) {
    renderTargetScene = new h2d.Scene();
    renderScene = new h2d.Scene();
    for (s2d in [renderScene]) {
      s2d.scaleMode = ScaleMode.Zoom(Main.Global.resolutionScale);
    }

    final sb = new SpriteBatchSystem(
        renderScene,
        hxd.Res.sprite_sheet_png,
        hxd.Res.sprite_sheet_json);

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
      final width = Main.nativePixelResolution.x;
      final height = Main.nativePixelResolution.y;
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

    lightingSb = {
      final sb = new SpriteBatchSystem(
        renderTargetScene,
        hxd.Res.sprite_sheet_png,
        hxd.Res.sprite_sheet_json);
      final batch = sb.batchManager.batch;
      batch.filter = new h2d.filter.Blur(5);
      batch.blendMode = h2d.BlendMode.Add;
      sb;
    }

    Main.Global.hooks.update.push(function syncToCamera(_) {
      final cam = Main.Global.mainCamera;
      final cam_center_x = -cam.x 
        + Math.fround(Main.Global.rootScene.width / 2);
      final cam_center_y = -cam.y 
        + Math.fround(Main.Global.rootScene.height / 2);

      lightingSb.setTranslate(
          cam_center_x,
          cam_center_y);

      return true;
    });
  }

  public function globalIlluminate(a = 0.2) {
    final cam = Main.Global.mainCamera;
    final s = lightingSb.emitSprite(
        cam.x - cam.w / 2,
        cam.y - cam.h / 2,
        'ui/square_white');
    s.alpha = a;
    s.scaleX = cam.w;
    s.scaleY = cam.h;

    return true;
  }

  public function render(e: h3d.Engine) {
    e.pushTarget(renderTarget);
    e.clear(0);
    renderTargetScene.render(e);
    e.popTarget();

    renderScene.render(e);
  }
}

class Experiment {
  public static function init() {
    final state = {
      isAlive: true
    };

    final scale = 4;
    final G = Main.Global;
    final sb = new SpriteBatchSystem(
        G.scene.staticScene,
        hxd.Res.sprite_sheet_png,
        hxd.Res.sprite_sheet_json);

    G.scene.staticScene.scaleMode = ScaleMode.Zoom(scale);

    function particleEffect(p: SpriteBatchSystem.SpriteRef) {
      final duration = 1.5;
      final progress = (G.time - p.createdAt) / duration;
      final colorProgress = Easing.easeOutExpo(progress);
      final sizeProgress = progress;
      final s = p.state;

      p.x = p.state.x + -p.state.dx * progress * 40;
      p.y = p.state.y + -p.state.dy * progress * 40;
      p.r = (1 - colorProgress);
      p.g = (1 - colorProgress);
      p.b = (1 - colorProgress);
      p.scale = sizeProgress * p.state.size;
      p.done = progress >= 1;
    }

    G.hooks.render.push((time) -> {
      final x = 200;
      final y = 100;

      final p = sb.emitSprite(
          x, 
          y, 
          'ui/gravity_field_core');
      p.sortOrder = 0;
      p.r = 0;
      p.g = 0;
      p.b = 0;
      p.scaleX = 1 + 0.1 * Math.sin(G.time * 2);
      p.scaleY = 1 + 0.1 * Math.cos(G.time * 2);

      if (Main.Global.tickCount % 10 == 0) {
        for (_ in 0...1) {
          final angle = Utils.rnd(0, 5) * Math.PI;
          final dx = Math.cos(angle);
          final dy = Math.sin(angle);
          final _x = x + dx * 40;
          final _y = y + dy * 40;
          final s = sb.emitSprite(
              _x,
              _y,
              'ui/gravity_field_particle');
          s.sortOrder = 2;
          s.effectCallback = particleEffect;
          s.state = {
            size: Utils.rnd(1, 1.2),
            x: _x,
            y: _y,
            dx: dx,
            dy: dy,
          };
        }
      }

      return true;
    });

    return () -> {
      state.isAlive = false;
    };
  }
}
