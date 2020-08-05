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

enum HoverState {
  None;
  LootHovered;
  // yet to be used
  LootHoveredCanPickup;
  Enemy;
  Ui;
}

class Global {
  public static var mainBackground: h2d.Scene;
  public static var rootScene: h2d.Scene;
  public static var particleScene: h2d.Scene;
  public static var uiRoot: h2d.Scene;
  public static var debugScene: h2d.Scene;
  public static var staticScene: h2d.Scene;

  public static var mainCamera: CameraRef;
  public static var worldMouse = {
    buttonDown: -1,
    buttonDownStartedAt: -1.0,
    clicked: false,
    hoverState: HoverState.None,
  }
  public static final obstacleGrid: GridRef = 
    Grid.create(16);
  public static final dynamicWorldGrid: GridRef = 
    Grid.create(16);
  public static var traversableGrid: GridRef = null;
  public static final lootColGrid: GridRef = 
    Grid.create(8);
  public static var sb: SpriteBatchSystem;
  public static var uiSpriteBatch: SpriteBatchSystem;
  public static var time = 0.0;
  public static var dt = 0.0;
  public static var tickCount = 0;
  public static var resolutionScale = 4;

  // for convenience, not sure if this is performant enough
  // for us to use for everything
  public static var updateHooks: 
    Array<(dt: Float) -> Bool> = [];
  public static var renderHooks: 
    Array<(dt: Float) -> Bool> = [];

  public static var mainPhase: MainPhase = null;
  public static var logData: Dynamic = {};
  public static var entitiesToRender: Array<Entity> = [];
  public static var uiState = {
    hud: {
      enabled: true
    },
    inventory: {
      opened: false
    }
  }

  public static var hoveredEntity = {
    id: Entity.NULL_ENTITY.id,
    hoverStart: -1.0
  };
  public static var tempState: Map<String, Float> = [
    'kamehamehaTick' => 0.0
  ];

  public static var fonts: {
    primary: h2d.Font,
    title: h2d.Font
  };

  public static var escapeStack: Stack.StackRef = [];
  public static var questActions = [];

  public static var questState = Quest.updateQuestState(
      {
        type: 'GAME_START',
        location: 'intro_level',
        data: null
      },
      new Map(),
      Quest.conditionsByName);
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
    var titleFont = Main.Global.fonts.title;
    var titleText = new h2d.Text(titleFont, this);
    titleText.text = 'Astral Cowboy';
    titleText.textColor = Game.Colors.pureWhite;
    titleText.x = leftMargin;
    titleText.y = 300;

    var btnFont = Main.Global.fonts.primary.clone();
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
        btnGroup.y += prevBtn.button.height + 10;
      }

      btn.x = btnGroup.x;
      btn.y = btnGroup.y;
    }
    
    Global.updateHooks.push((dt: Float) -> {
      for (o in uiButtonsList) {
        var btn = (o: UiButton);
        btn.update(dt);
      }

      final isActive = parent != null;

      Global.uiState.hud.enabled = !isActive;

      return isActive;
    });

    Global.renderHooks.push((time) -> {
      Global.uiSpriteBatch.emitSprite(
          0, 0,
          'ui/square_white',
          null,
          (p) -> {
            final win = hxd.Window.getInstance();

            p.batchElement.r = 0;
            p.batchElement.g = 0;
            p.batchElement.b = 0;
            p.batchElement.a = 0.7;

            p.batchElement.scaleX = win.width;
            p.batchElement.scaleY = win.height;
          });

      return parent != null;
    });
  }
}

enum abstract MainSceneType(String) {
  var PlayGame;
}

class Main extends hxd.App {
  var anim: h2d.Anim;
  var debugText: h2d.Text;
  var acc = 0.0;
  var game: Game;
  var background: h2d.Graphics;
  var sceneCleanupFn: () -> Void;
  public static final nativePixelResolution = {
    // TODO this should be based on
    // the actual screen's resolution
    x: 1920,
    y: 1080
  };

  function addBackground(s2d: h2d.Scene, color) {
    final g = new h2d.Graphics(s2d);
    final scale = Global.resolutionScale;
    
    g.blendMode = h2d.BlendMode.Add;
    g.beginFill(color);
    g.drawRect(
        0, 0, 
        s2d.width * scale, 
        s2d.height * scale);

    final colorA = 0xd10a7e;
    final colorB = 0x0095e9;
    final p = new hxd.Perlin();

    // make stars
    final divisor = 6;
    final xMax = Std.int((1920 + 20) / scale / divisor);
    final yMax = Std.int((1080 + 20) / scale / divisor);
    final seed = Utils.irnd(0, 100);
    final starSizes = [0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 3];
    for (x in 0...xMax) {
      for (y in 0...yMax) {
        final v = p.perlin(seed, x / yMax, y / xMax, 10);
        final color = 0xffffff;
        g.beginFill(color, Math.abs(v) * 3);
        g.drawCircle(
            x * divisor + Utils.irnd(-5, 5, true), 
            y * divisor + Utils.irnd(-5, 5, true), 
            Utils.rollValues(starSizes) / 6,
            4);
      }
    }

    // make nebula "clouds"
    final divisor = 1.5;
    final xMax = Std.int((1920 + 20) / scale / divisor);
    final yMax = Std.int((1080 + 20) / scale / divisor);
    final seed = Utils.irnd(0, 100);
    for (x in 0...xMax) {
      for (y in 0...yMax) {
        final v = p.perlin(seed, x / yMax, y / xMax, 15, 0.25);
        final color = v > 0 ? colorA : colorB;
        g.beginFill(color, Math.abs(v) / 12);
        g.drawCircle(
            x * divisor, 
            y * divisor, 
            2,
            4);
      }
    }

    return g;
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
    try {

      Main.Global.mainPhase = MainPhase.Render;

      // prepare all sprite batches 
      if (game != null) {
        game.render(Global.time);
      }

      {
        final nextRenderHooks = [];
        for (hook in Global.renderHooks) {
          final keepAlive = hook(Global.time);

          if (keepAlive) {
            nextRenderHooks.push(hook);
          }
        }
        Global.renderHooks = nextRenderHooks;
      }

      core.Anim.AnimEffect
        .render(Global.time);
      // run sprite batches before engine rendering
      SpriteBatchSystem.renderAll(Global.time);

      Global.mainBackground.render(e);
      super.render(e);
      Global.particleScene.render(e);
      Global.staticScene.render(e);
      Global.uiRoot.render(e);
      Global.debugScene.render(e);

    } catch (error: Dynamic) {

      final stack = haxe.CallStack.exceptionStack();
      trace(error);
      trace(haxe.CallStack.toString(stack));
      hxd.System.exit();

    }
  }

  override function init() {
    try {
      // final sceneToLoad = 'editor';
      final sceneToLoad = 'game';

      final scenes = [
        'editor' => () -> {
          Editor.init();

          return () -> {};
        },
        'game' => () -> {
          game = new Game(s2d, game);
          Stack.push(Global.escapeStack, 'goto home screen', () -> {
            var hs = showHomeScreen();
            Global.uiRoot.addChild(hs);

            Stack.push(Global.escapeStack, 'back to game', () -> {
              hs.remove();
            });
          });
          Hud.InventoryDragAndDropPrototype
            .addTestItems();

          return () -> {};
        }
      ];

      hxd.Res.initEmbed();
      Main.Global.mainPhase = MainPhase.Init;

      Main.Global.fonts = {
        primary: Fonts.primary(),
        title: Fonts.title()
      };

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

        // used for experimental projects
        Global.staticScene = new h2d.Scene();
        sevents.addScene(Global.staticScene);

        background = addBackground(
            Global.mainBackground, 0x222222);
      }

#if !production

      Tests.run();      

#end

      final win = hxd.Window.getInstance();

      {
        final rootInteract = new h2d.Interactive(
            nativePixelResolution.x,
            nativePixelResolution.y,
            Global.uiRoot);

        rootInteract.propagateEvents = true;
        rootInteract.enableRightButton = true;

        var pointerDownAt = 0.0;

        rootInteract.onClick = (_) -> {
          // Click events trigger regardless of how long
          // since the pointer was down. This fixes that.
          final timeBetweenPointerDown = Global.time - pointerDownAt;
          final clickTimeTolerance = 0.3; // seconds

          if (timeBetweenPointerDown > clickTimeTolerance) {
            return;
          }

          Global.worldMouse.clicked = true;

          return;
        };

        rootInteract.onPush = (event : hxd.Event) -> {
          pointerDownAt = Global.time;
          Global.worldMouse.buttonDownStartedAt = Global.time;
          Global.worldMouse.buttonDown = event.button;
        };

        rootInteract.onRelease = (event : hxd.Event) -> {
          Global.worldMouse.buttonDown = -1;
        };
      }

      // setup viewport
#if !jsMode
      {
        // make fullscreen
        win.resize(
            nativePixelResolution.x, 
            nativePixelResolution.y);
        win.displayMode = hxd.Window.DisplayMode
          .Fullscreen;
      }
#end

      Global.mainCamera = Camera.create();
      
      Global.sb = new SpriteBatchSystem(
          Global.particleScene);
      Global.uiSpriteBatch = new SpriteBatchSystem(
          Global.uiRoot);


#if debugMode
      var font = hxd.res.DefaultFont.get();
      setupDebugInfo(font);
#end

      sceneCleanupFn = scenes.get(sceneToLoad)();
      Hud.init();

    } catch (error: Dynamic) {

      final stack = haxe.CallStack.exceptionStack();
      trace(error);
      trace(haxe.CallStack.toString(stack));
      hxd.System.exit();

    }
  }

  function handleGlobalHotkeys() {
    final Key = hxd.Key;

#if debugMode
    final isForceExit = Key.isDown(Key.CTRL) &&
      Key.isPressed(Key.Q);

    if (isForceExit) {
      hxd.System.exit();
    }
#end

    if (Key.isPressed(Key.I)) {
      Hud.UiStateManager.send({
        type: 'INVENTORY_TOGGLE'
      });
    }

    if (Key.isPressed(Key.ESCAPE)) {
      Stack.pop(Global.escapeStack);
    }
  }

  // on each frame
  override function update(dt:Float) {
    try {
      {
        // reset scene data each update
        Global.staticScene.x = 0;
        Global.staticScene.y = 0;
        Global.staticScene.scaleMode = ScaleMode.Zoom(1);
      }

      Global.logData.escapeStack = Global.escapeStack;
      Global.mainPhase = MainPhase.Update;

      // set to 1/60 for a fixed 60fps
      var frameTime = dt;
      var fps = Math.round(1/dt);

      if (debugText != null) {
        final formattedStats = Json.stringify({
          time: Global.time,
          tickCount: Global.tickCount,
          fpsTrue: fps,
          fps: Math.round(1/frameTime),
          drawCalls: engine.drawCalls,
          numEntities: Lambda.count(Entity.ALL_BY_ID),
          numSprites: Lambda.fold(
              SpriteBatchSystem.instances, 
              (ref, count) -> {
                return count + ref.particles.length;
              }, 0),
          numActiveEntitiesToRender: 
            Main.Global.entitiesToRender.length,
          numAnimations: core.Anim.AnimEffect
            .nextAnimations.length,
          numUpdateHooks: Main.Global.updateHooks.length,
          numRenderHooks: Main.Global.renderHooks.length,
        }, null, '  ');
        var text = [
          'stats: ${formattedStats}',
          'log: ${Json.stringify(Global.logData, null, '  ')}'
        ].join('\n');
        var debugUiMargin = 10;
        debugText.x = debugUiMargin;
        debugText.y = debugUiMargin;
        debugText.text = text;
      }
        
      Global.dt = dt;
      Global.time += dt;

      handleGlobalHotkeys();

      acc += dt;

      var isNextFrame = acc >= frameTime;
      // handle fixed dt here
      if (isNextFrame) {
        acc -= frameTime;

        if (game != null) {
          game.update(s2d, frameTime);
        }
      }

      final nextHooks = [];
      for (update in Main.Global.updateHooks) {
        final shouldKeepAlive = update(dt);

        if (shouldKeepAlive) {
          nextHooks.push(update); 
        }
      }
      Main.Global.updateHooks = nextHooks;

      core.Anim.AnimEffect
        .update(dt);
      SpriteBatchSystem.updateAll(dt);
      // sync up scenes with the camera
      {
        // IMPORTANT: update the camera position first
        // before updating the scenes otherwise they
        // will be lagging behind
        Camera.update(Main.Global.mainCamera, dt);
        Camera.setSize(
            Main.Global.mainCamera,
            Main.Global.rootScene.width,
            Main.Global.rootScene.height);

        // update scenes to move relative to camera
        var cam_center_x = -Main.Global.mainCamera.x 
          + Math.fround(Main.Global.rootScene.width / 2);
        var cam_center_y = -Main.Global.mainCamera.y 
          + Math.fround(Main.Global.rootScene.height / 2);
        for (scene in [
            Main.Global.rootScene,
            Main.Global.particleScene,
            Main.Global.debugScene
        ]) {
          scene.x = cam_center_x;
          scene.y = cam_center_y;
        }
      }

      final tickFrequency = 144;
      Main.Global.tickCount = Std.int(
          Main.Global.time / (1 / tickFrequency));

      Global.worldMouse.clicked = false;
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
