import Mob;

class BatchDraw {
  var txt: h2d.Text;
  var texture: h3d.mat.Texture;
  var customGraphics: h2d.Graphics;

  public function new(s2d: h2d.Scene, font) {
    texture = new h3d.mat.Texture(s2d.height, s2d.width, [h3d.mat.Data.TextureFlags.Target]);
    final tile = h2d.Tile.fromTexture(texture);
    var bmp = new h2d.Bitmap(tile, s2d);

    customGraphics = new h2d.Graphics(bmp);
    customGraphics.beginFill(0xFFF);
    for (i in 0...200) {
      customGraphics.drawCircle(50, 50 + i, 100);
    }
    customGraphics.endFill();

    txt = new h2d.Text(font, bmp);
    for (i in 0...100) {
      var t = new h2d.Text(font, bmp);
      t.y = 400 + i * 5;
      t.text = 'blah ${i}';
    }

    bmp.x = 50;

    for (i in 0...30) {
      txt.y = i * 10 + 200;
      txt.text = 'hello ${i}';
      txt.drawTo(texture);
    }
  }

  public function update(t, dt:Float, s2d: h2d.Scene) {
    texture.clear(0x000, 0);

    txt.text = "foobar";
    txt.y = Math.sin(t) * 30 + 100;
  }
}

class Main extends hxd.App {
  var anim: h2d.Anim;
  var debugText: h2d.Text;
  var tickCount = 0;
  var t = 0.0;
  var acc = 0.0;
  var batcher: BatchDraw;
  var mob: Mob;
  var background: h2d.Bitmap;

  function animate(s2d: h2d.Scene) {
    // creates three tiles with different color
    var t1 = h2d.Tile.fromColor(0xFF0000, 30, 30);
    var t2 = h2d.Tile.fromColor(0x00FF00, 30, 40);
    var t3 = h2d.Tile.fromColor(0x0000FF, 30, 50);

    // creates an animation for these tiles
    anim = new h2d.Anim([t1,t2,t3], s2d);
    anim.x = s2d.width * 0.5;
    anim.y = s2d.height * 0.5;
  }

  function addBackground(s2d: h2d.Scene, color) {
    // background
    var overlayTile = h2d.Tile.fromColor(color, s2d.width, s2d.height);
    return new h2d.Bitmap(overlayTile, s2d);
  }

  function setupDebugInfo(font) {
    var debugUiMargin = 10;
    debugText = new h2d.Text(font);
    debugText.x = debugUiMargin;
    debugText.y = debugUiMargin;

    // add to any parent, in this case we append to root
    s2d.addChild(debugText);
  }

  override function init() {
    var font: h2d.Font = hxd.res.DefaultFont.get();

    background = addBackground(s2d, 0x333333);
    setupDebugInfo(font);

    mob = new Mob(s2d);
  }

  // on each frame
  override function update(dt:Float) {
    t += dt;
    acc += dt;

    var frameTime = dt;
    var fps = Math.round(1/dt);
    var text = ['time: ${t}',
                'fps: ${fps}',
                'drawCalls: ${engine.drawCalls}'].join('\n');
    debugText.text = text;

    var isNextFrame = acc >= frameTime;
    // handle fixed dt here
    if (isNextFrame) {
      acc -= frameTime;
      mob.update(s2d, frameTime);
    }

    background.width = s2d.width;
    background.height = s2d.height;
  }

  static function main() {
    new Main();
  }
}