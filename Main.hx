import haxe.Json;
import h2d.Text;
import h2d.Interactive;
import Fonts;
import Game;
import Grid;
import ParticlePlayground;
import Camera;
import Tests;
import Collision;

class Global {
  public static var mainBackground: h2d.Scene;
  public static var rootScene: h2d.Scene;
  public static var particleScene: h2d.Scene;
  public static var uiRoot: h2d.Scene;
  public static var debugScene: h2d.Scene;

  public static var mainCamera: CameraRef;
  public static var mouse = {
    buttonDown: -1
  }
  public static var obstacleGrid: GridRef;
  public static var dynamicWorldGrid: GridRef;
  public static var traversableGrid: GridRef;
  public static var sb: ParticlePlayground;
  public static var pixelScale = 4;
  public static var time = 0.0;
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

    var buttons: Array<Dynamic> = [
      ['Start Game', btnFont, () -> {
        this.remove();
        onGameStart();
      }],
      ['Map Editor', btnFont, onMapEditorMode],
      ['Particle Playground', btnFont, onParticlePlaygroundMode],
      ['Exit Game', btnFont, onGameExit],
    ];

    var btnGroup = {
      x: leftMargin,
      y: titleText.y + titleText.textHeight + 50
    }
    for (i in 0...buttons.length) {
      var config: Array<Dynamic> = buttons[i];
      var prevBtn = uiButtonsList[i - 1];
      var btn = new UiButton(config[0], config[1], config[2]);
      addChild(btn);
      uiButtonsList.push(btn);

      if (prevBtn != null) {
        btnGroup.y += prevBtn.button.height;
      }

      btn.x = btnGroup.x;
      btn.y = btnGroup.y;
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
    t.textAlign = Right;
    t.textColor = Game.Colors.pureWhite;
    helpTextList.push(t);
    return t;
  }

  public function new(s2d: h2d.Scene) {
    super(s2d);

    scene = s2d;
    var font = Fonts.primary.get().clone();
    font.resizeTo(24);
    controlsHelpText('wasd: move', font);
    controlsHelpText('left-click: primary', font);
    controlsHelpText('right-click: secondary', font);
  }

  public function update(dt) {
    var _originX = scene.width - 10.0;
    var originY = scene.height - 10;

    for (t in helpTextList) {
      t.x = _originX;
      t.y = originY - t.textHeight;
      _originX -= t.textWidth + 20;
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

  public override function render(e: h3d.Engine) {
    Global.mainBackground.render(e);
    super.render(e);
    Global.particleScene.render(e);
    Global.uiRoot.render(e);
    Global.debugScene.render(e);
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
    // setup scenes
    {
      Global.uiRoot = new h2d.Scene();
      sevents.addScene(Global.uiRoot);

      Global.particleScene = new h2d.Scene();
      Global.mainBackground = new h2d.Scene();
      Global.debugScene = new h2d.Scene();

      background = addBackground(Global.mainBackground, 0x333333);
    }

    try {
      // Tests.run();
    } catch (err: Dynamic) {
      var font = Fonts.primary.get().clone();
      font.resizeTo(12 * 2);
      var tf = new h2d.Text(font, Global.debugScene);
      tf.textColor = Game.Colors.red;
      tf.textAlign = Align.Center;
      var stack = haxe.CallStack.exceptionStack();
      tf.text = haxe.CallStack.toString(stack);
    }

    {
      function onEvent(event : hxd.Event) {
        if (event.kind == hxd.Event.EventKind.EPush) {
          Global.mouse.buttonDown = event.button;
        }
        if (event.kind == hxd.Event.EventKind.ERelease) {
          Global.mouse.buttonDown = -1;
        }
      }
      hxd.Window.getInstance().addEventTarget(onEvent);
    }

    {
      var win = hxd.Window.getInstance();

      // make fullscreen
      #if !jsMode
        win.resize(1920, 1080);
        win.displayMode = hxd.Window.DisplayMode.Fullscreen;
      #end
    }

    hxd.Res.initEmbed();

    Global.rootScene = s2d;

    Global.mainCamera = Camera.create();
    Global.sb = new ParticlePlayground();

    switchMainScene(MainSceneType.PlayGame);

    #if debugMode
      var font = Fonts.primary.get().clone();
      setupDebugInfo(font);
    #end
  }

  function handleGlobalHotkeys() {
    var Key = hxd.Key;

    if (Key.isPressed(Key.ESCAPE)) {
      switchMainScene(MainSceneType.PlayGame);
    }
  }

  // on each frame
  override function update(dt:Float) {
    Main.Global.time += dt;

    Camera.setSize(
      Main.Global.mainCamera,
      Main.Global.rootScene.width,
      Main.Global.rootScene.height
    );

    // update scenes to move relative to camera
    var cam_center_x = -Main.Global.mainCamera.x + Math.fround(Main.Global.mainCamera.w / 2);
    var cam_center_y = -Main.Global.mainCamera.y + Math.fround(Main.Global.mainCamera.h / 2);
    for (scene in [
      Main.Global.rootScene,
      Main.Global.particleScene,
      Main.Global.debugScene
    ]) {
      scene.x = cam_center_x;
      scene.y = cam_center_y;
    }

    handleGlobalHotkeys();

    for (it in reactiveItems) {
      it.update(dt);
    }

    acc += dt;

    // set to 1/60 for a fixed 60fps
    var frameTime = dt;
    var fps = Math.round(1/dt);
    var isNextFrame = acc >= frameTime;
    // handle fixed dt here
    if (isNextFrame) {
      acc -= frameTime;

      if (game != null) {
        var levelCleared = game.isLevelComplete();
        if (levelCleared) {
          game.newLevel(s2d);
        }

        game.update(s2d, frameTime);
        Global.sb.update(frameTime);

        if (game.isGameOver()) {
          switchMainScene(MainSceneType.PlayGame);
        }
      }

      Camera.update(Main.Global.mainCamera, dt);

      if (debugText != null) {
        var text = [
          'stats: ${Json.stringify({
            time: Main.Global.time,
            fpsTrue: fps,
            fps: Math.round(1/frameTime),
            drawCalls: engine.drawCalls,
            numEntities: Entity.ALL.length,
            numParticles: Main.Global.sb.pSystem.particles.length
          }, null, '  ')}',
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
