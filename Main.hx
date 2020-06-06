import haxe.Json;
import h2d.Text;
import h2d.Interactive;
import Fonts;
import Game;
import Grid;
import ParticlePlayground;
import Camera;

class Global {
  public static var rootScene: h2d.Scene;
  public static var uiRoot: h2d.Scene;
  public static var mainBackground: h2d.Scene;
  public static var debugCanvas: h2d.Graphics;
  public static var mainCamera: CameraRef;
  public static var mouse = {
    isDown: false
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

  public function new(
    onGameStart,
    onGameExit,
    onMapEditorMode,
    onParticlePlaygroundMode
  ) {
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
      'Start Game', btnFont, () -> {
        this.remove();
        onGameStart();
      }
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

    var mapEditorModeBtn = new UiButton(
      'Map Editor', btnFont, onMapEditorMode
    );
    addChild(mapEditorModeBtn);
    mapEditorModeBtn.x = exitGameBtn.x;
    mapEditorModeBtn.y = exitGameBtn.y + startGameBtn.button.height + 10;
    uiButtonsList.push(mapEditorModeBtn);

    var particlePlaygroundModeBtn = new UiButton(
      'Particle Playground', btnFont, onParticlePlaygroundMode
    );
    addChild(particlePlaygroundModeBtn);
    particlePlaygroundModeBtn.x = mapEditorModeBtn.x;
    particlePlaygroundModeBtn.y = mapEditorModeBtn.y + mapEditorModeBtn.button.height + 10;
    uiButtonsList.push(particlePlaygroundModeBtn);
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

enum abstract MainSceneType(String) {
  var PlayGame;
  var MapEditor;
  var ParticlePlayground;
}


class Main extends hxd.App {
  var anim: h2d.Anim;
  var debugText: h2d.Text;
  var tickCount = 0;
  var t = 0.0;
  var acc = 0.0;
  var game: Game;
  var background: h2d.Bitmap;
  var reactiveItems: Map<String, Dynamic> = new Map();

  function addBackground(s2d: h2d.Scene, color) {
    // background
    var overlayTile = h2d.Tile.fromColor(color, s2d.width, s2d.height);
    return new h2d.Bitmap(overlayTile, s2d);
  }

  function setupDebugInfo(font) {
    debugText = new h2d.Text(font);
    // debugText.textAlign = Right;

    // add to any parent, in this case we append to root
    Global.uiRoot.addChild(debugText);
  }

  function onGameExit() {
    trace('on game exit');
    hxd.System.exit();
  }

  function showHomeScreen() {
    game.remove();
    game = null;

    function onGameStart() {
      game = new Game(s2d, game);
    }

    return new HomeScreen(
      onGameStart, onGameExit,
      () -> {
        switchMainScene(MainSceneType.MapEditor);
      },
      () -> {
        switchMainScene(MainSceneType.ParticlePlayground);
      }
    );
  }

  function runTests() {
    Grid.tests();
    SaveState.tests();
  }

  public override function render(e: h3d.Engine) {
    Global.mainBackground.render(e);
    super.render(e);
    Global.uiRoot.render(e);
  }

  function switchMainScene(sceneType: MainSceneType) {
    for (key => ref in reactiveItems) {
      ref.remove();
      reactiveItems.remove(key);
    }

    switch(sceneType) {
      case MainSceneType.PlayGame: {
        var hud = new Hud(Global.uiRoot);
        Global.uiRoot.addChild(hud);
        reactiveItems['MainScene_PlayGame_Hud'] = hud;
        var hs = showHomeScreen();
        Global.uiRoot.addChild(hs);
        reactiveItems['MainScene_PlayGame_HomeScreen'] = hs;
      }

      case MainSceneType.MapEditor: {
        var editor = new GridEditor(s2d);
        reactiveItems['MainScene_GridEditor'] = editor;
      }

      case MainSceneType.ParticlePlayground: {
        var ref = new ParticlePlayground();
        reactiveItems['MainScene_ParticlePlayground'] = ref;
      }
    }
  }

  override function init() {
    {
      function onEvent(event : hxd.Event) {
        if (event.kind == hxd.Event.EventKind.EPush) {
          Global.mouse.isDown = true;
        }
        if (event.kind == hxd.Event.EventKind.ERelease) {
          Global.mouse.isDown = false;
        }
      }
      hxd.Window.getInstance().addEventTarget(onEvent);
    }

    hxd.Res.initEmbed();

    {
      var win = hxd.Window.getInstance();

      // make fullscreen
      #if !jsMode
        win.displayMode = hxd.Window.DisplayMode.Fullscreen;
      #end
    }

    Global.uiRoot = new h2d.Scene();
    sevents.addScene(Global.uiRoot);

    Global.mainBackground = new h2d.Scene();

    background = addBackground(Global.mainBackground, 0x222222);
    runTests();

    Global.rootScene = s2d;
    Global.mainCamera = Camera.create();

    switchMainScene(MainSceneType.ParticlePlayground);

    #if debugMode
      setupDebugInfo(Fonts.primary.get());
    #end

    Global.debugCanvas = new h2d.Graphics(s2d);
  }

  function handleGlobalHotkeys() {
    var Key = hxd.Key;

    if (Key.isPressed(Key.ESCAPE)) {
      switchMainScene(MainSceneType.PlayGame);
    }
  }

  // on each frame
  override function update(dt:Float) {
    Camera.setSize(
      Main.Global.mainCamera,
      Main.Global.rootScene.width,
      Main.Global.rootScene.height
    );

    Main.Global.rootScene.x = -Main.Global.mainCamera.x +
      Math.fround(Main.Global.mainCamera.w / 2);
    Main.Global.rootScene.y = -Main.Global.mainCamera.y +
      Math.fround(Main.Global.mainCamera.h / 2);
    handleGlobalHotkeys();

    for (it in reactiveItems) {
      it.update(dt);
    }

    t += dt;
    acc += dt;

    // set to 1/60 for a fixed 60fps
    var frameTime = dt;
    var fps = Math.round(1/dt);
    var isNextFrame = acc >= frameTime;
    // handle fixed dt here
    if (isNextFrame) {
      acc -= frameTime;

      Global.debugCanvas.clear();

      if (game != null) {
        var levelCleared = game.isLevelComplete();
        if (levelCleared) {
          game.newLevel(s2d);
        }

        game.update(s2d, frameTime);

        if (game.isGameOver()) {
          switchMainScene(MainSceneType.PlayGame);
        }
      }

      Camera.update(Main.Global.mainCamera, dt);

      if (debugText != null) {
        var text = [
          'time: ${t}',
          'fpsTrue: ${fps}',
          'fps: ${Math.round(1/frameTime)}',
          'drawCalls: ${engine.drawCalls}',
          'numEntities: ${Entity.ALL.length}',
          'mouse: ${Json.stringify(Global.mouse, null, '  ')}'
        ].join('\n');
        var debugUiMargin = 10;
        debugText.x = debugUiMargin;
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