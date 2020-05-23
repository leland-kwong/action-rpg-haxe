import h2d.Text;
import h2d.Interactive;
import Fonts;
import Game;
import Grid;

class Global {
  public static var rootScene: h2d.Scene;
}

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

enum UiState {
  Over;
  Normal;
}

class UiButton extends h2d.Object {
  var text: h2d.Text;
  var state: UiState;
  public var button: Interactive;

  public function new(btnText, font, onClick) {
    super();

    text = new Text(font);
    text.text = btnText;

    button = new Interactive(
      text.textWidth,
      text.textHeight
    );

    button.onOver = function(ev: hxd.Event) {
      state = UiState.Over;
    }

    button.onOut = function(ev: hxd.Event) {
      state = UiState.Normal;
    }

    button.onClick = function(ev: hxd.Event) {
      onClick();
    }

    button.addChild(text);
    addChild(button);
  }

  public function update(dt) {
    if (state == UiState.Normal) {
      text.textColor = Game.Colors.pureWhite;
    }

    if (state == UiState.Over) {
      text.textColor = Game.Colors.yellow;
    }
  }
}
class HomeScreen extends h2d.Object {
  var uiButtonsList = [];

  public function new(s2d, onGameStart, onGameExit) {
    super();

    var leftMargin = 100;

    var titleFont = Fonts.primary.get().clone();
    titleFont.resizeTo(12 * 6);
    var titleText = new h2d.Text(titleFont, this);
    titleText.text = 'Autonomous';
    titleText.textColor = Game.Colors.pureWhite;
    titleText.x = leftMargin;
    titleText.y = 300;

    var btnFont = Fonts.primary.get().clone();
    btnFont.resizeTo(36);

    var startGameBtn = new UiButton(
      'Start Game', btnFont, onGameStart
    );
    addChild(startGameBtn);
    startGameBtn.x = leftMargin;
    startGameBtn.y = titleText.y + titleText.textHeight + 50;
    uiButtonsList.push(startGameBtn);

    var exitGameBtn = new UiButton(
      'Exit Game', btnFont, onGameExit
    );
    addChild(exitGameBtn);
    exitGameBtn.x = startGameBtn.x;
    exitGameBtn.y = startGameBtn.y + startGameBtn.button.height + 10;
    uiButtonsList.push(exitGameBtn);
  }

  override function onRemove() {
    trace('homescreen remove');
    for (o in uiButtonsList) {
      o.remove();
    }
  }

  public function update(dt: Float) {
    for (o in uiButtonsList) {
      var btn = (o: UiButton);
      btn.update(dt);
    }
  }
}

class Hud extends h2d.Object {
  var helpTextList: Array<h2d.Text> = [];
  var scene: h2d.Scene;

  function controlsHelpText(text, font) {
    var t = new h2d.Text(font, this);
    t.text = text;
    t.textColor = Game.Colors.pureWhite;
    helpTextList.push(t);
    return t;
  }

  public function new(s2d: h2d.Scene) {
    super();

    scene = s2d;
    var font = Fonts.primary.get().clone();
    font.resizeTo(24);
    controlsHelpText('wasd: move', font);
    controlsHelpText('left-click: primary', font);
    controlsHelpText('right-click: secondary', font);
  }

  public function update() {
    var _originX = 10.0;
    var originY = scene.height - 10;

    for (t in helpTextList) {
      t.x = _originX;
      t.y = originY - t.textHeight;
      _originX += t.textWidth + 20;
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
  var game: Game;
  var background: h2d.Bitmap;
  var homeScreen: HomeScreen;
  var hud: Hud;
  var reactiveItems: Array<Dynamic> = [];

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
    debugText = new h2d.Text(font);
    debugText.textAlign = Right;

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

  function showHomeScreen() {
    if (homeScreen != null) {
      return;
    }

    // reset game states
    game.remove();
    game = null;

    function onGameStart() {
      game = new Game(s2d, game);
      homeScreen.remove();
      homeScreen = null;
    }

    function onGameExit() {
      trace('on game exit');
      hxd.System.exit();
    }
    homeScreen = new HomeScreen(
      s2d, onGameStart, onGameExit
    );
    s2d.addChild(homeScreen);
  }

  override function init() {
    Global.rootScene = s2d;

    #if !jsMode
    // make fullscreen
    {
      hxd.Window.getInstance()
        .displayMode = hxd.Window.DisplayMode.Fullscreen;
    }
    #end

    background = addBackground(s2d, 0x222222);

    // showHomeScreen();
    // hud = new Hud(s2d);
    // s2d.addChild(hud);
    // reactiveItems.push(hud);

    reactiveItems.push(
      new GridExample(s2d)
    );
    Grid.test();

    #if debugMode
      setupDebugInfo(Fonts.primary.get());
    #end
  }

  function handleGlobalHotkeys() {
    var Key = hxd.Key;

    if (Key.isPressed(Key.ESCAPE)) {
      showHomeScreen();
    }
  }

  // on each frame
  override function update(dt:Float) {
    handleGlobalHotkeys();

    for (it in reactiveItems) {
      it.update(dt);
    }

    t += dt;
    acc += dt;

    // fixed to 60fps for now
    var frameTime = 1/60;
    var fps = Math.round(1/dt);
    var isNextFrame = acc >= frameTime;
    // handle fixed dt here
    if (isNextFrame) {
      acc -= frameTime;

      var numEnemies = getNumEnemies();

      if (game != null) {
        var levelCleared = numEnemies == 0;
        if (levelCleared) {
          game.newLevel(s2d);
        }

        game.update(s2d, frameTime);
        // batcher.update(t, dt, s2d);

        if (game.isGameOver()) {
          showHomeScreen();
        }
      }

      if (homeScreen != null) {
        homeScreen.update(dt);
      }

      if (debugText != null) {
        var text = [
          'time: ${t}',
          'fps: ${fps}',
          'drawCalls: ${engine.drawCalls}',
          'numEntities: ${Entity.ALL.length}',
          'numEnemies: ${numEnemies}'
        ].join('\n');
        var debugUiMargin = 10;
        debugText.x = s2d.width - debugUiMargin;
        debugText.y = debugUiMargin;
        debugText.text = text;
      }
    }

    background.width = s2d.width;
    background.height = s2d.height;
  }

  static function main() {
    new Main();
  }
}