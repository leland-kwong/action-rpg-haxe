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
  public static var inactiveAbilitiesRoot: h2d.Scene;
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
  public static var isNextFrame = true;

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

enum abstract MainSceneType(String) {
  var PlayGame;
}

class Main extends hxd.App {
  var anim: h2d.Anim;
  var debugText: h2d.Text;
  var acc = 0.0;
  var background: h2d.Graphics;
  var sceneCleanupFn: () -> Void;
  public static final nativePixelResolution = {
    // TODO this should be based on
    // the actual screen's resolution
    x: 1920,
    y: 1080
  };

  function setupDebugInfo(font) {
    debugText = new h2d.Text(font);
    // debugText.textAlign = Right;

    // add to any parent, in this case we append to root
    Global.uiRoot.addChild(debugText);
  }

  function onGameExit() {
    hxd.System.exit();

    return () -> {};
  }

  public override function render(e: h3d.Engine) {
    try {

      Main.Global.mainPhase = MainPhase.Render;

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
      Global.inactiveAbilitiesRoot.render(e);
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

      hxd.Res.initEmbed();
      Main.Global.mainPhase = MainPhase.Init;

      Main.Global.fonts = {
        primary: Fonts.primary(),
        title: Fonts.title()
      };

      // setup global scene objects
      {
        Global.rootScene = s2d;
        s2d.scaleMode = ScaleMode.Zoom(
            Global.resolutionScale);

        Global.uiRoot = new h2d.Scene();
        sevents.addScene(Global.uiRoot);

        Global.inactiveAbilitiesRoot = {
          final s2d = new h2d.Scene();
          s2d.filter = h2d.filter.ColorMatrix.grayed();
          s2d;
        }

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

        // setup sprite batch systems
        Global.sb = new SpriteBatchSystem(
            Global.particleScene,
            hxd.Res.sprite_sheet_png,
            hxd.Res.sprite_sheet_json);
        Global.uiSpriteBatch = new SpriteBatchSystem(
            Global.uiRoot,
            hxd.Res.sprite_sheet_png,
            hxd.Res.sprite_sheet_json);

      }

#if !production

      Tests.run();      

#end

      final win = hxd.Window.getInstance();

      // setup global mouse interactions
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
        
        {
          final spriteSheetRes = hxd.Res.sprite_sheet_ui_cursor_png;
          final spriteSheetData: SpriteBatchSystem.SpriteSheetData = 
            Utils.loadJsonFile(
              hxd.Res.sprite_sheet_ui_cursor_json);
          final cursorSpriteData: SpriteBatchSystem.SpriteData = 
            Reflect.field(
                spriteSheetData.frames, 'default-0');
          final f = cursorSpriteData.frame;
          final targetCursorFrames = {
            final pixels = spriteSheetRes.getPixels(RGBA);
            final colorTeal = 0x2ce8f5;
            final bmp = new hxd.BitmapData(f.w, f.h);
            final dst = haxe.io.Bytes.alloc(f.w * f.h * 4);
            final subSpritePixels = new hxd.Pixels(
                f.w, f.h, dst, RGBA); 

            // draw the pixels from the sprite
            // to generate a custom cursor
            for (y in f.y...(f.y + f.h)) {
              for (x in f.x...(f.x + f.w)) {
                final px = pixels.getPixel(x, y);
                subSpritePixels.setPixel(
                    x - f.x, y - f.y, px);
              }
            }
            bmp.setPixels(subSpritePixels);

            [bmp];
          }

          final Cursor = hxd.Cursor;
          final targetCursor = Cursor.Custom(
              new hxd.Cursor.CustomCursor(
                targetCursorFrames, 
                0, 
                Std.int(f.w / 2), 
                Std.int(f.h / 2)));

          function handleCursorStyle(dt) {
            final hoverState = Global.worldMouse.hoverState;

            rootInteract.cursor = switch(hoverState) {
              case 
                HoverState.LootHovered
                | HoverState.LootHoveredCanPickup
                | HoverState.Enemy: targetCursor;

              default: Cursor.Default;
            }

            return true;
          }

          Global.updateHooks.push(handleCursorStyle);
        }
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

#if debugMode
      var font = hxd.res.DefaultFont.get();
      setupDebugInfo(font);
#end

      Gui.init();
      Hud.init();

      final homeMenuOptions = [
        ['newGame', 'New Game'],
        ['editor', 'Editor'],
        ['experiment', 'Experiment'],
        ['exit', 'Exit']
      ];

      function initGame() {
        final gameRef = new Game(s2d); 

        Global.uiState.hud.enabled = true;

        Hud.InventoryDragAndDropPrototype
          .addTestItems();

        return () -> gameRef.remove();
      }

      function onHomeMenuSelect(value) {
        if (sceneCleanupFn != null && 
            value != 'backToGame') {
          sceneCleanupFn();
        }

        // execute selection
        sceneCleanupFn = switch(value) {
          case 'experiment': Experiment.init();
          case 'editor': Editor.init();
          case 'exit': onGameExit();
          case 'newGame': initGame();
          default: {
            throw 'home screen menu case not handled';
          };
        }

        Global.escapeStack = [];

        function homeScreenOnEscape() {
          Stack.push(Global.escapeStack, 'goto home screen', () -> {
            Global.uiState.hud.enabled = false;
            final closeHomeMenu = Gui.homeMenu(
                onHomeMenuSelect, homeMenuOptions);

            Stack.push(Global.escapeStack, 'back to game', () -> {
              closeHomeMenu();
              homeScreenOnEscape();
              Global.uiState.hud.enabled = true;
            });
          });
        }

        homeScreenOnEscape();

        return true;
      }

      Gui.homeMenu(
          onHomeMenuSelect, homeMenuOptions);

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
      Global.isNextFrame = false;

      {
        // reset scene data each update
        Global.staticScene.x = 0;
        Global.staticScene.y = 0;
        Global.staticScene.scaleMode = ScaleMode.Zoom(4);
      }

      Global.logData.escapeStack = Global.escapeStack;
      Global.mainPhase = MainPhase.Update;
      Global.dt = dt;
      Global.time += dt;
      acc += dt;

      var fps = Math.round(1/dt);
      // set to 1/60 for a fixed 60fps
      final frameTime = Global.dt;

      // update dt accumulator
      var isNextFrame = acc >= frameTime;
      if (isNextFrame) {
        acc -= frameTime;
        Global.isNextFrame = true;
      }


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

      handleGlobalHotkeys();

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
