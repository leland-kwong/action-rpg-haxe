class Main extends hxd.App {
  var anim: h2d.Anim;
  var tf: h2d.Text;
  var tickCount = 0;
  var t = 0.0;

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
    var overlay = new h2d.Bitmap(overlayTile, s2d);
    overlay.x = 0;
    overlay.y = 0;
  }

  override function init() {
    addBackground(s2d, 0x333333);
    animate(s2d);

    var font: h2d.Font = hxd.res.DefaultFont.get();
    var debugUiMargin = 10;
    tf = new h2d.Text(font);
    tf.x = debugUiMargin;
    tf.y = debugUiMargin;

    // add to any parent, in this case we append to root
    s2d.addChild(tf);
  }
  // on each frame
  override function update(dt:Float) {
    t += dt;
    var text = ['time: ${t}',
                'fps: ${Math.round(1/dt)}'].join('\n');
    // show debug info
    tf.text = text;
  }
  static function main() {
    new Main();
  }
}