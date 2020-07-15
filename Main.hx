import haxe.Json;
import h2d.Text;
import h2d.Interactive;
import Fonts;
import Game;
import Grid;
import SpriteBatchSystem;
import Camera;
import Tests;
import Collision;

enum MainPhase {
  Init;
  Update;
  Render;
}

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
  public static var entitiesToRenderGrid = 
    Grid.create(135);
  public static var traversableGrid: GridRef;
  public static var sb: SpriteBatchSystem;
  public static var uiSpriteBatch: SpriteBatchSystem;
  public static var time = 0.0;
  public static var dt = 0.0;
  public static var playerStats: PlayerStats.StatsRef = null; 
  public static var resolutionScale = 4;
  public static var updateHooks: 
    Array<(dt: Float) -> Void> = [];
  public static var renderHooks: 
    Array<(dt: Float) -> Void> = [];
  public static var mainPhase: MainPhase = null;
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
      onGameExit
      ) {
    super();

    var leftMargin = 100;

    var titleFont = Fonts.primary.get().clone();
    titleFont.resizeTo(12 * 6);
    var titleText = new h2d.Text(titleFont, this);
    titleText.text = 'Astral Cowboy';
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

enum abstract MainSceneType(String) {
  var PlayGame;
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
    function onGameStart() {
      game = new Game(s2d, game);
    }

    return new HomeScreen(
      onGameStart, onGameExit);
  }

  public override function render(e: h3d.Engine) {
    Main.Global.mainPhase = MainPhase.Render;

    // prepare all sprite batches 
    if (game != null) {
      game.render(Global.time);
    }
    for (hook in Global.renderHooks) {
      hook(Global.time);
    }
    Hud.render(Global.time);
    core.Anim.AnimEffect
      .render(Global.time);
    // run sprite batches before engine rendering
    SpriteBatchSystem.renderAll(Global.time);

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
        var hs = showHomeScreen();
        Global.uiRoot.addChild(hs);
        reactiveItems['MainScene_PlayGame_HomeScreen'] = hs;
      }
    }
  }

  override function init() {
    try {
      Main.Global.mainPhase = MainPhase.Init;

      // setup scenes
      {
        Global.rootScene = s2d;
        s2d.scaleMode = ScaleMode.Zoom(
            Global.resolutionScale);

        Global.uiRoot = new h2d.Scene();
        sevents.addScene(Global.uiRoot);

        Global.particleScene = new h2d.Scene();
        Global.particleScene.scaleMode = ScaleMode.Zoom(
            Global.resolutionScale);

        Global.mainBackground = new h2d.Scene();
        Global.mainBackground.scaleMode = ScaleMode.Zoom(
            Global.resolutionScale);
        Global.debugScene = new h2d.Scene();

        background = addBackground(
            Global.mainBackground, 0x333333);
      }

#if !production

      Tests.run();      

#end

      {
        function onEvent(event : hxd.Event) {
          if (event.kind == hxd.Event.EventKind.EPush) {
            Global.mouse.buttonDown = event.button;
          }
          if (event.kind == hxd.Event.EventKind.ERelease) {
            Global.mouse.buttonDown = -1;
          }
        }
        hxd.Window.getInstance()
          .addEventTarget(onEvent);
      }

      // setup viewport
#if !jsMode
      {
        var win = hxd.Window.getInstance();
        // make fullscreen
        var nativePixelResolution = {
          // TODO this should be based on
          // the actual screen's resolution
          x: 1920,
          y: 1080
        }
        win.resize(
            nativePixelResolution.x, 
            nativePixelResolution.y);
        win.displayMode = hxd.Window.DisplayMode
          .Fullscreen;
      }
#end

      hxd.Res.initEmbed();

      Global.mainCamera = Camera.create();
      
      Global.sb = new SpriteBatchSystem(
          Global.particleScene);
      Global.uiSpriteBatch = new SpriteBatchSystem(
          Global.uiRoot);

      switchMainScene(MainSceneType.PlayGame);

#if debugMode
      var font = Fonts.primary.get().clone();
      setupDebugInfo(font);
#end

      Hud.start();

    } catch (error: Dynamic) {

      final stack = haxe.CallStack.exceptionStack();
      trace(error);
      trace(haxe.CallStack.toString(stack));
      hxd.System.exit();

    }
  }

  function handleGlobalHotkeys() {
    var Key = hxd.Key;

    if (Key.isPressed(Key.ESCAPE)) {
      switchMainScene(MainSceneType.PlayGame);
    }
  }

  // on each frame
  override function update(dt:Float) {
    try {
      Main.Global.mainPhase = MainPhase.Update;

      // set to 1/60 for a fixed 60fps
      var frameTime = dt;
      var fps = Math.round(1/dt);

      if (debugText != null) {
        final formattedStats = Json.stringify({
          time: Global.time,
          fpsTrue: fps,
          fps: Math.round(1/frameTime),
          drawCalls: engine.drawCalls,
          numEntities: Entity.ALL.length,
          numSprites: Lambda.fold(
              SpriteBatchSystem.instances, 
              (ref, count) -> {
                return count + ref.particles.length;
              }, 0),
          numAnimations: core.Anim.AnimEffect
            .nextAnimations.length
        }, null, '  ');
        var text = [
          'stats: ${formattedStats}',
          'mouse: ${Json.stringify(Global.mouse, null, '  ')}',
        ].join('\n');
        var debugUiMargin = 10;
        debugText.x = debugUiMargin;
        debugText.y = debugUiMargin;
        debugText.text = text;
      }
        
      Global.dt = dt;
      Global.time += dt;

      handleGlobalHotkeys();

      for (it in reactiveItems) {
        it.update(dt);
      }

      acc += dt;

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

          if (game.isGameOver()) {
            switchMainScene(MainSceneType.PlayGame);
          }
        }
      }

      background.width = s2d.width;
      background.height = s2d.height;

      for (update in Main.Global.updateHooks) {
        update(dt);
      }

      core.Anim.AnimEffect
        .update(dt);
      SpriteBatchSystem.updateAll(dt);

    } catch (error: Dynamic) {

      final stack = haxe.CallStack.exceptionStack();
      trace(error);
      trace(haxe.CallStack.toString(stack));
      hxd.System.exit();

    }
  }

  static function main() {
    new Main();
  }
}
