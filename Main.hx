import Mob;

class BatchDraw {
  var txt: h2d.Text;
  var batch: h2d.SpriteBatch;
  var graphic: h2d.Graphics;
  var circleTile: h2d.Tile;
  var squareTile: h2d.Tile;

  public function new(s2d: h2d.Scene, font) {
    var texture = new h3d.mat.Texture(s2d.height, s2d.width, [h3d.mat.Data.TextureFlags.Target]);
    var tile = h2d.Tile.fromTexture(texture);
    circleTile = tile.sub(0, 0, 51 * 2, 51 * 2);

    graphic = new h2d.Graphics(s2d);
    // outline
    graphic.beginFill(0xffffff);
    graphic.drawCircle(51, 51, 51);
    // fill
    graphic.beginFill(0x999);
    graphic.drawCircle(51, 51, 50);

    var squareX = 50 + 102;
    var squareY = 51;
    squareTile = tile.sub(squareX, squareY, 50, 50);
    graphic.beginFill(0xffda3d);
    graphic.drawRect(squareX, squareY, 50, 50);
    graphic.endFill();
    graphic.drawTo(texture);
  }

  public function update(t, dt:Float, s2d: h2d.Scene) {
    graphic.clear();

    for (i in 0...10000) {
      var x = i % 50 * 2 + 100 + Std.random(100);
      var y = Math.round(i / 2) + Std.random(100);
      var tile = i % 2 == 0 ? circleTile : squareTile;
      var centerOffsetX = tile.width / 2;
      var centerOffsetY = tile.height / 2;
      graphic.drawTile(
        x + Math.sin(t) * 100 - centerOffsetX,
        y - centerOffsetY,
        tile
      );
    }
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
  var level = 0;

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

  function getNumEnemies() {
    var numEnemies = 0;
    for (e in Entity.ALL) {
      if (e.type == 'ENEMY') {
        numEnemies += 1;
      }
    }
    return numEnemies;
  }

  override function init() {
    var font: h2d.Font = hxd.res.DefaultFont.get();

    background = addBackground(s2d, 0x333333);
    mob = new Mob(s2d);

    setupDebugInfo(font);
  }

  // on each frame
  override function update(dt:Float) {
    t += dt;
    acc += dt;

    var numEnemies = getNumEnemies();
    var levelCleared = numEnemies == 0;
    if (levelCleared) {
      level += 1;
      mob.newLevel(s2d, level);
    }

    var frameTime = 1/60;
    var fps = Math.round(1/dt);
    var text = ['time: ${t}',
                'fps: ${fps}',
                'drawCalls: ${engine.drawCalls}',
                'numEnemies: ${numEnemies}'].join('\n');
    debugText.text = text;

    var isNextFrame = acc >= frameTime;
    // handle fixed dt here
    if (isNextFrame) {
      acc -= frameTime;
      mob.update(s2d, frameTime);
      // batcher.update(t, dt, s2d);
    }

    background.width = s2d.width;
    background.height = s2d.height;
  }

  static function main() {
    new Main();
  }
}