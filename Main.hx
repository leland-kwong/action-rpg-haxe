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
import Gui;

enum MainPhase {
  Init;
  Update;
  Render;
}

enum HoverState {
  None;
  Ui;
}

typedef VoidFn = () -> Void;

class Global {
  public static var mainBackground: h2d.Scene;
  public static var rootScene: h2d.Scene;
  public static var particleScene: h2d.Scene;
  public static var obstacleMaskScene: h2d.Scene;
  public static var obscuredEntitiesScene: h2d.Scene;
  public static var staticScene: h2d.Scene;
  public static var inactiveAbilitiesRoot: h2d.Scene;
  public static var uiRoot: h2d.Scene;
  public static var debugScene: h2d.Scene;

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
  public static var wmSpriteBatch: SpriteBatchSystem;
  public static var oeSpriteBatch: SpriteBatchSystem;
  public static var uiSpriteBatch: SpriteBatchSystem;
  public static var time = 0.0;
  public static var isNextFrame = true;

  public static var tickCount = 0.;
  public static var resolutionScale = 4;

  // for convenience, not sure if this is performant enough
  // for us to use for everything
  public static var updateHooks: 
    Array<(dt: Float) -> Bool> = [];
  public static var renderHooks: 
    Array<(dt: Float) -> Bool> = [];
  // handles input device events
  public static var inputHooks: 
    Array<(dt: Float) -> Bool> = [];

  public static var mainPhase: MainPhase = null;
  public static var logData: Dynamic = {};
  public static var entitiesToRender: Array<Entity> = [];
  public static var uiState = {
    mainMenu: {
      enabled: true
    },
    hud: {
      enabled: true
    },
    inventory: {
      enabled: false
    },
    passiveSkillTree: {
      enabled: false
    }
  }
  public static var uiHomeMenuEnabled = true;

  public static var hoveredEntity = {
    id: Entity.NULL_ENTITY.id,
    hoverStart: -1.0
  };
  public static var gameState = Session.createGameState(
      -1, null, null, 'placeholder_game_state');

  static var sceneCleanupFn: () -> Void;

  public static function replaceScene(
      getNextScene: () -> VoidFn) {
    if (sceneCleanupFn != null) {
      sceneCleanupFn();
    } 

    sceneCleanupFn = getNextScene();
  }

  public static function clearUi(
      shouldClear: (field: String) -> Bool): Bool {
    final wereUiItemsClosed = Lambda.fold(
        Reflect.fields(Global.uiState),
        (field, result) -> {
          if (!shouldClear(field)) {
            return result;
          }

          final state = Reflect.field(Global.uiState, field);
          final enabled = state.enabled;

          state.enabled = false;
        
          if (enabled) {
            return true;
          }      

          return result;
        }, false);

    return wereUiItemsClosed;
  }

  public static function hasUiItemsEnabled() {
    final uiPanelFields = Lambda.filter(
        Reflect.fields(Global.uiState),
        (field) -> field != 'hud');

    return Lambda.exists(
        uiPanelFields,
        (field) -> {
          return Reflect.field(Global.uiState, field).enabled;
        });
  }
}

enum UiState {
  Over;
  Normal;
}

class Main extends hxd.App {
  var anim: h2d.Anim;
  var debugText: h2d.Text;
  var acc = 0.0;
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

  public static function onGameExit() {
    hxd.System.exit();

    return () -> {};
  }

  public override function render(e: h3d.Engine) {
    try {

      Global.mainPhase = MainPhase.Render;

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

      Global.obstacleMaskScene.render(e);
      Global.mainBackground.render(e);
      super.render(e);
      Global.particleScene.render(e);
      Global.obscuredEntitiesScene.render(e);
      Global.staticScene.render(e);
      Global.inactiveAbilitiesRoot.render(e);
      Global.uiRoot.render(e);
      Global.debugScene.render(e);

    } catch (error: Dynamic) {
      HaxeUtils.handleError(
          null, 
          (_) -> hxd.System.exit())(error);
    }
  }

  function handleGlobalHotkeys(dt: Float) {
    final Key = hxd.Key;

#if debugMode
    final isForceExit = Key.isDown(Key.CTRL) &&
      Key.isPressed(Key.Q);

    if (isForceExit) {
      hxd.System.exit();
    }
#end

    // handle in game hotkeys
    if (!Global.uiState.mainMenu.enabled) {
      if (Key.isPressed(Key.I)) {
        Hud.UiStateManager.send({
          type: 'INVENTORY_TOGGLE'
        });
      }

      final togglePassiveSkillTree = 
        Key.isPressed(Key.P);
      if (togglePassiveSkillTree) {
        Hud.UiStateManager.send({
          type: 'PASSIVE_SKILL_TREE_TOGGLE'
        });
      }
    }

    final toggleMainMenu = 
      Key.isPressed(Key.ESCAPE);
    if (toggleMainMenu) {
      // close all open ui elements first
      final wereUiItemsClosed = Global.clearUi((field) -> {
        return field != 'hud'; 
      });

      // only show main menu if there were no elements closed
      if (!wereUiItemsClosed) {
        Global.uiState.mainMenu.enabled = true;  
      }
    }

    return true;
  }

  override function init() {
    try {
      hxd.Res.initEmbed();
      Global.mainPhase = MainPhase.Init;
      Global.inputHooks.push(handleGlobalHotkeys);

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

        {
          Global.obstacleMaskScene = new h2d.Scene();
          Global.obstacleMaskScene.scaleMode = ScaleMode.Zoom(
              Global.resolutionScale);
          Global.obscuredEntitiesScene = new h2d.Scene();
          Global.obscuredEntitiesScene.scaleMode = ScaleMode.Zoom(
              Global.resolutionScale);
        }

        // used for experimental projects
        Global.staticScene = new h2d.Scene();
        sevents.addScene(Global.staticScene);

        // setup sprite batch systems
        Global.sb = new SpriteBatchSystem(
            Global.particleScene,
            hxd.Res.sprite_sheet_png,
            hxd.Res.sprite_sheet_json);
        {
          Global.wmSpriteBatch = new SpriteBatchSystem(
              Global.obstacleMaskScene,
              hxd.Res.sprite_sheet_png,
              hxd.Res.sprite_sheet_json);
          Global.oeSpriteBatch = new SpriteBatchSystem(
              Global.obscuredEntitiesScene,
              hxd.Res.sprite_sheet_png,
              hxd.Res.sprite_sheet_json);
          final mask = new h2d.filter.Mask(
              Global.obstacleMaskScene, true, true);
          final batch = Global.oeSpriteBatch.batchManager.batch;
          batch.filter = mask;
          batch.color = new h3d.Vector(1, 1, 1, 0.7);
          batch.colorAdd = new h3d.Vector(1, 1, 1, 1);
        }
        Global.uiSpriteBatch = new SpriteBatchSystem(
            Global.uiRoot,
            hxd.Res.sprite_sheet_png,
            hxd.Res.sprite_sheet_json);
      }

      Tests.run();      

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
        
        // setup custom cursor graphic
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

          function deriveCursorStyle() {
            if (Global.hasUiItemsEnabled()) {
              return Cursor.Default;
            }

            return targetCursor;
          }

          function updateCursorStyle(dt) {
            rootInteract.cursor = deriveCursorStyle();

            return true;
          }

          Global.updateHooks.push(updateCursorStyle);
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
      setupDebugInfo(Fonts.debug());
#end

      Gui.init();
      Gui.GuiComponents.mainMenu();
      Hud.init();
      PassiveSkillTree.init();
    } catch (error: Dynamic) {
      HaxeUtils.handleError(
          '[update error]',
          (_) -> hxd.System.exit())(error);
    }
  }

  
  function hasRemainingUpdateFrames(
      acc: Float, frameTime: Float) {
    return acc >= frameTime;
  }

  // on each frame
  override function update(dt:Float) {
    try {
      Global.isNextFrame = false;
      Global.mainPhase = MainPhase.Update;
      acc += dt;

      final trueFps = Math.round(1/dt);
      
      // Set to fixed dt otherwise we can get inconsistent
      // results with the game physics.
      // https://gafferongames.com/post/fix_your_timestep/
      final frameTime = 1/100;
      // prevent updates from cascading into infinite
      final maxNumUpdatesPerFrame = 4;
      var frameDt = 0.;
      var numUpdates = 0;

      TextPool.resetAll();

      // run while there is remaining frames to simulate
      while (hasRemainingUpdateFrames(acc, frameTime)
          && numUpdates < maxNumUpdatesPerFrame) {
        numUpdates += 1;

        acc -= frameTime;
        Global.isNextFrame = true;

        Global.time += frameTime;
        frameDt += frameTime;

        // run updateHooks
        {
          final nextHooks = [];
          for (update in Global.updateHooks) {
            final shouldKeepAlive = update(frameTime);

            if (shouldKeepAlive) {
              nextHooks.push(update); 
            }
          }
          Global.updateHooks = nextHooks;
        }

        // sync up scenes with the camera
        {
          // IMPORTANT: update the camera position first
          // before updating the scenes otherwise they
          // will be lagging behind
          Camera.update(Global.mainCamera, frameTime);
          Camera.setSize(
              Global.mainCamera,
              Global.rootScene.width,
              Global.rootScene.height);

          // update scenes to move relative to camera
          final cam_center_x = -Global.mainCamera.x 
            + Math.fround(Global.rootScene.width / 2);
          final cam_center_y = -Global.mainCamera.y 
            + Math.fround(Global.rootScene.height / 2);
          for (scene in [
              Global.rootScene,
              Global.particleScene,
              Global.obstacleMaskScene,
              Global.obscuredEntitiesScene,
          ]) {
            scene.x = cam_center_x;
            scene.y = cam_center_y;
          }
        }

        // ints (under 8 bytes in size) can only be a maximum of 10^10 before they wrap over
        // and become negative values. So to get around this, we floor a float value to achieve the same thing.
        Global.tickCount = Math.ffloor(
            Global.time / frameTime);

        // we want to set this to false as soon as
        // a single update is run to prevent a situation
        // where we'll get a double click due to the game
        // loop updating more than once per frame on systems
        // that don't support high frame rates
        Global.worldMouse.clicked = false;
      }
      
      // run input hooks outside of the main update loop
      // because we only want it to trigger once per
      // frame.
      {
        final nextHooks = [];
        for (update in Global.inputHooks) {
          final shouldKeepAlive = update(frameTime);

          if (shouldKeepAlive) {
            nextHooks.push(update); 
          }
        }
        Global.inputHooks = nextHooks;
      }

      if (debugText != null) {
        final stats = {
          time: Global.time,
          tickCount: Global.tickCount,
          trueFps: trueFps,
          updatesPerFrame: Math.round(1/frameTime),
          drawCalls: engine.drawCalls,
          numEntities: Lambda.count(Entity.ALL_BY_ID),
          numSprites: Lambda.fold(
              SpriteBatchSystem.instances, 
              (ref, count) -> {
                return count + ref.particles.length;
              }, 0),
          numActiveEntitiesToRender: 
            Global.entitiesToRender.length,
          numAnimations: core.Anim.AnimEffect
            .nextAnimations.length,
          numUpdateHooks: Global.updateHooks.length,
          numInputHooks: Global.inputHooks.length,
          numRenderHooks: Global.renderHooks.length,
        }
        final formattedStats = Json.stringify(stats, null, '  ');
        final text = [
          'stats: ${formattedStats}',
          'log: ${Json.stringify(Global.logData, null, '  ')}'
        ].join('\n');
        debugText.x = Gui.margin;
        debugText.y = Gui.margin;
        debugText.text = text;
        Global.logData.maxParticles = Math.max(
            Global.logData.maxParticles,
            stats.numSprites);
        Global.logData.totalParticles =
          Utils.withDefault(
              Global.logData.totalParticles, 0) 
          + stats.numSprites;
        Global.logData.avgParticles = Std.int(
            Global.logData.totalParticles / Global.tickCount);
      }

      core.Anim.AnimEffect
        .update(frameDt);
      SpriteBatchSystem.updateAll(frameDt);

      // version info
      {
        final tf = TextPool.get();
        final win = hxd.Window.getInstance();
        tf.font = Fonts.debug();
        tf.text = 'build ${Config.version}';
        tf.x = win.width - tf.textWidth - Gui.margin;
        tf.y = win.height - tf.textHeight - Gui.margin;
      }

    } catch (error: Dynamic) {
      HaxeUtils.handleError(
          '[update error]',
          (_) -> hxd.System.exit())(error);
    }
  }

  static function main() {
    new Main();
  }
}
