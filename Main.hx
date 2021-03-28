import haxe.Json;

class Main extends hxd.App {
  private static final nativePixelResolution = {
    // TODO this should be based on
    // the actual screen's resolution
    x: 1920,
    y: 1080
  };

  var acc = 0.0;
  public var time = 0.0;
  public var tickCount = 0.0;
  public override function render(e: h3d.Engine) {
    try {
    } catch (error: Dynamic) {
      HaxeUtils.handleError(
          null, 
          (_) -> hxd.System.exit())(error);
    }
  }

  override function init() {
    try {
      // setup viewport
#if !jsMode
      {
        final win = hxd.Window.getInstance(); 
        // make fullscreen
        win.resize(
            nativePixelResolution.x, 
            nativePixelResolution.y);
        win.displayMode = hxd.Window.DisplayMode
          .Fullscreen;
      }
#end

#if debugMode
#end

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

      // run while there is remaining frames to simulate
      while (hasRemainingUpdateFrames(acc, frameTime)
          && numUpdates < maxNumUpdatesPerFrame) {
        numUpdates += 1;

        acc -= frameTime;
        // ints (under 8 bytes in size) can only be a maximum of 10^10 before they wrap over
        // and become negative values. So to get around this, we floor a float value to achieve the same thing.
        tickCount = Math.ffloor(
            time / frameTime);
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
