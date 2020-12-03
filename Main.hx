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
import LightingSystem;

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

class SceneGroup {
  public var mainBackground: h2d.Scene;
  public var uiRoot: h2d.Scene;
  public var inactiveAbilitiesRoot: h2d.Scene;
  public var particle: h2d.Scene;
  public var obstacleMask: h2d.Scene;
  public var obscuredEntities: h2d.Scene;
  public var staticScene: h2d.Scene;

  public function new(sevents: hxd.SceneEvents): Void {
    mainBackground = {
      final s = new h2d.Scene();
      s.scaleMode = ScaleMode.Zoom(
          Global.resolutionScale);
      s;
    }

    uiRoot = {
      final s = new h2d.Scene();
      sevents.addScene(s);
      s;
    }

    inactiveAbilitiesRoot = {
      final s = new h2d.Scene();
      s.filter = h2d.filter.ColorMatrix.grayed();
      s;
    }

    particle = {
      final s = new h2d.Scene();
      s.scaleMode = ScaleMode.Zoom(
          Global.resolutionScale);
      s;
    }

    obstacleMask = {
      final s = new h2d.Scene();
      s.scaleMode = ScaleMode.Zoom(
          Global.resolutionScale);
      s;
    }

    obscuredEntities = {
      final s = new h2d.Scene();
      s.scaleMode = ScaleMode.Zoom(
          Global.resolutionScale);
      s;
    }

    staticScene = {
      final s = new h2d.Scene();
      sevents.addScene(s);
      s;
    }
  }
}

class Global {
  public static var time = 0.0;
  public static var isNextFrame = true;
  public static var tickCount = 0.;
  public static var resolutionScale = 4.;
  public static var logData: Dynamic = {};
  
  public static var scene: SceneGroup = null;
  public static var rootScene: h2d.Scene;

  public static var mainCamera: CameraRef;
  public static var worldMouse = {
    buttonDown: -1,
    buttonDownStartedAt: -1.0,
    clicked: false,
    hoverState: HoverState.None,
  }
  public static final grid = {
    obstacle: Grid.create(16),
    dynamicWorld: Grid.create(16),
    traversable: Grid.create(16),
    lootCol: Grid.create(8),
  }
  public static var sb: SpriteBatchSystem;
  public static var wmSpriteBatch: SpriteBatchSystem;
  public static var oeSpriteBatch: SpriteBatchSystem;
  public static var uiSpriteBatch: SpriteBatchSystem;

  public static final hooks = {
    update: new Array<(dt: Float) -> Bool>(),
    render: new Array<(time: Float) -> Bool>(),
    // handles input device events
    input: new Array<(dt: Float) -> Bool>(),
  }

  public static var mainPhase: MainPhase = null;
  public static var entitiesToRender: Array<Entity> = [];
  public static var uiState = Hud.UiStateManager.nextUiState(
      Hud.UiStateManager.defaultUiState, {
        mainMenu: {
          enabled: true
        }
      });
  // enables/disables home menu toggling so pressing
  // escape doesn't open it under certain conditions
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

class AutoCleanupGameObjects {
  static var items: Array<h2d.Object> = [];

  public static function add(o: h2d.Object) {
    items.push(o);
  }

  public static function clear() {
    for (o in items) {
      o.remove();
    }
    items = [];
  }
}

class Main extends hxd.App {
  var anim: h2d.Anim;
  var debugText: h2d.Text;
  var acc = 0.0;
  public static var cursorStyle: {
    target: hxd.Cursor,
    interact: hxd.Cursor,
    _default: hxd.Cursor
  }
  public static final nativePixelResolution = {
    // TODO this should be based on
    // the actual screen's resolution
    x: 1920,
    y: 1080
  };
  public static var lightingSystem: LightingSystem;

  function setupDebugInfo(font) {
    debugText = new h2d.Text(font, Global.scene.uiRoot);
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
        for (hook in Global.hooks.render) {
          final keepAlive = hook(Global.time);

          if (keepAlive) {
            nextRenderHooks.push(hook);
          }
        }
        Global.hooks.render = nextRenderHooks;
      }

      core.Anim.AnimEffect
        .render(Global.time);
      // run sprite batches before engine rendering
      SpriteBatchSystem.renderAll(Global.time);

      Global.scene.obstacleMask.render(e);
      Global.scene.mainBackground.render(e);
      super.render(e);
      Global.scene.particle.render(e);
      Global.scene.obscuredEntities.render(e);
      Global.scene.staticScene.render(e);
      lightingSystem.render(e);
      Global.scene.uiRoot.render(e);
      Global.scene.inactiveAbilitiesRoot.render(e);

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
      final modifierPressed = Key.isDown(Key.CTRL);
      if (!modifierPressed) {
        if (Key.isPressed(Key.I)) {
          Hud.UiStateManager.send({
            type: 'UI_INVENTORY_TOGGLE'
          });
        }

        final togglePassiveSkillTree = 
          Key.isPressed(Key.P);
        if (togglePassiveSkillTree) {
          Hud.UiStateManager.send({
            type: 'UI_PASSIVE_SKILL_TREE_TOGGLE'
          });
        }
      }

      // debug hotkeys
#if debugMode
      final toggleLightingDebug = Key.isDown(Key.CTRL)
          && Key.isPressed(Key.NUMBER_0);
      if (toggleLightingDebug) {
        Main.lightingSystem.debugShadows = 
          !Main.lightingSystem.debugShadows;
      }

      final triggerPlayerDamage = Key.isDown(Key.CTRL)
          && Key.isPressed(Key.NUMBER_1);
      if (triggerPlayerDamage) {
        EntityStats.addEvent(
            Entity.getById('PLAYER').stats, {
              type: 'DAMAGE_RECEIVED',
              value: {
                baseDamage: 1,
                sourceStats: EntityStats.placeholderStats,
              }
            });
      }

      final toggleHitboxDebug = Key.isDown(Key.CTRL)
        && Key.isPressed(Key.NUMBER_2);
      if (toggleHitboxDebug) {
        Entity.debug.collisionHitbox = !Entity.debug.collisionHitbox;
      }
    }
#end

    final toggleMainMenu = 
      Key.isPressed(Key.ESCAPE);
    if (toggleMainMenu) {
      Hud.UiStateManager.send({
        type: 'UI_MAIN_MENU_TOGGLE'
      });
    }

    return true;
  }

  override function init() {
    try {
      hxd.Res.initEmbed();
      Global.mainPhase = MainPhase.Init;
      Global.hooks.input.push(handleGlobalHotkeys);

      // setup global scene objects
      {
        Global.scene = new SceneGroup(sevents);
        Global.rootScene = s2d;
        s2d.scaleMode = ScaleMode.Zoom(
            Global.resolutionScale);

        // setup sprite batch systems
        Global.sb = new SpriteBatchSystem(
            Global.scene.particle,
            hxd.Res.sprite_sheet_png,
            hxd.Res.sprite_sheet_json,
            SpriteBatchSystem.ySort);
        {
          Global.wmSpriteBatch = new SpriteBatchSystem(
              Global.scene.obstacleMask,
              hxd.Res.sprite_sheet_png,
              hxd.Res.sprite_sheet_json,
              SpriteBatchSystem.ySort);
          Global.oeSpriteBatch = new SpriteBatchSystem(
              Global.scene.obscuredEntities,
              hxd.Res.sprite_sheet_png,
              hxd.Res.sprite_sheet_json,
              SpriteBatchSystem.ySort);
          final mask = new h2d.filter.Mask(
              Global.scene.obstacleMask, true, true);
          final batch = Global.oeSpriteBatch.batchManager.batch;
          batch.filter = mask;
          batch.color = new h3d.Vector(1, 1, 1, 0.7);
          batch.colorAdd = new h3d.Vector(1, 1, 1, 1);
        }
        Global.uiSpriteBatch = new SpriteBatchSystem(
            Global.scene.uiRoot,
            hxd.Res.sprite_sheet_png,
            hxd.Res.sprite_sheet_json,
            SpriteBatchSystem.ySort);
      }

      Tests.run();      

      final win = hxd.Window.getInstance();

      // setup global mouse interactions
      {
        final rootInteract = new h2d.Interactive(
            nativePixelResolution.x,
            nativePixelResolution.y,
            Global.scene.uiRoot);

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
                spriteSheetData.frames, 'default-0--main');
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
          cursorStyle = {
            target: Cursor.Custom(
              new hxd.Cursor.CustomCursor(
                targetCursorFrames, 
                0, 
                Std.int(f.w / 2), 
                Std.int(f.h / 2))),
            interact: Cursor.Button,
            _default: Cursor.Default,
          };

          function deriveCursorStyle() {
            if (Global.hasUiItemsEnabled()) {
              return cursorStyle._default;
            }

            return cursorStyle.target;
          }

          function updateCursorStyle(dt) {
            rootInteract.cursor = deriveCursorStyle();

            return true;
          }

          Global.hooks.update.push(updateCursorStyle);
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

      lightingSystem = new LightingSystem(engine);

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

      TextManager.resetAll();
      AutoCleanupGameObjects.clear();

      // run input hooks outside of the main update loop
      // because we only want it to trigger once per
      // frame.
      {
        final nextHooks = [];
        for (update in Global.hooks.input) {
          final shouldKeepAlive = update(frameTime);

          if (shouldKeepAlive) {
            nextHooks.push(update); 
          }
        }
        Global.hooks.input = nextHooks;
        Global.worldMouse.clicked = false;
      }

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
          for (update in Global.hooks.update) {
            final shouldKeepAlive = update(frameTime);

            if (shouldKeepAlive) {
              nextHooks.push(update); 
            }
          }
          Global.hooks.update = nextHooks;
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
          Camera.setZoom(
              Global.mainCamera,
              Global.resolutionScale);

          // update scenes to move relative to camera
          final cam_center_x = -Global.mainCamera.x 
            + Math.fround(Global.rootScene.width / 2);
          final cam_center_y = -Global.mainCamera.y 
            + Math.fround(Global.rootScene.height / 2);
          for (scene in [
              Global.rootScene,
              Global.scene.particle,
              Global.scene.obstacleMask,
              Global.scene.obscuredEntities,
          ]) {
            scene.x = cam_center_x;
            scene.y = cam_center_y;
          }
          Main.lightingSystem.sb.setTranslate(
              cam_center_x,
              cam_center_y);
        }

        // ints (under 8 bytes in size) can only be a maximum of 10^10 before they wrap over
        // and become negative values. So to get around this, we floor a float value to achieve the same thing.
        Global.tickCount = Math.ffloor(
            Global.time / frameTime);
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
          numUpdateHooks: Global.hooks.update.length,
          numInputHooks: Global.hooks.input.length,
          numRenderHooks: Global.hooks.render.length,
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
        final tf = TextManager.get();
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
