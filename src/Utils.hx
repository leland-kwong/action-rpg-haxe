#if jsMode
import js.Browser;
#end

class Utils {
  public static function clamp(value: Float, min: Float, max: Float) {
    if (value < min) {
      return min;
    }

    if (value > max) {
      return max;
    }

    return value;
  }

  public static function distanceSqr(ax:Float,ay:Float,bx:Float,by:Float) : Float {
    return (ax-bx)*(ax-bx) + (ay-by)*(ay-by);
  }

  public static function distance(ax:Float,ay:Float, bx:Float,by:Float) : Float {
    return Math.sqrt( distanceSqr(ax,ay,bx,by) );
  }

  public static function rnd(min:Float, max:Float, ?sign=false) {
    if( sign )
      return (min + Math.random()*(max-min)) * (Std.random(2)*2-1);
    else
      return min + Math.random()*(max-min);
  }

  public static function irnd(min:Int, max:Int, ?sign:Bool) {
    if( sign )
      return (min + Std.random(max-min+1)) * (Std.random(2)*2-1);
    else
      return min + Std.random(max-min+1);
  }

  static var idsCreated = 0;
  static var idSeed = '${Math.random()}'.substring(2, 8);
  public static function uid(
    isUnique: (id: String) -> Bool = null
  ): String {
    idsCreated += 1;
    var id = '${idSeed}-${idsCreated}';

    if (isUnique != null && !isUnique(id)) {
      return uid(isUnique);
    }

    return id;
  }

  public static var BRESENHAM_DONE = 1;
  // creates a line using bresenham's line algorithm
  public static function bresenhamLine(
    x1, y1, x2, y2, callback: (ctx: Dynamic, x: Int, y: Int, i: Int) -> Bool, context = null
  ) {
    var MAX_NUM_ITERATIONS = 5000;

    var dx = Math.abs(x2 - x1);
    var dy = Math.abs(y2 - y1);
    var sign_x = (x1 < x2) ? 1 : -1;
    var sign_y = (y1 < y2) ? 1 : -1;
    var err = dx - dy;
    var num_iterations = 0;

    while (true) {
      if (num_iterations > MAX_NUM_ITERATIONS) {
        throw "[bresenham line error] Too many calls. This is not normal behavior.";
      }

      var is_end_of_line = ((x1 == x2) && (y1 == y2));
      var shouldContinue = callback(context, x1, y1, num_iterations);

      if (!shouldContinue || is_end_of_line) {
        return;
      }

      var e2 = 2 * err;
      if (e2 > -dy) {
        err = err - dy;
        x1  = x1 + sign_x;
      }

      if (e2 < dx) {
        err = err + dx;
        y1  = y1 + sign_y;
      }

      num_iterations += 1;
    }
  }

  public static function hrt(): Float {
    #if jsMode
    var window = Browser.window;
    return window.performance.now();
    #end

    /**
      TODO
      Add support for native
    **/
    return 0.0;
  }

  public static function loadJsonFile(res: hxd.res.Resource) {
    var path = Std.string(res);

    return haxe.Json.parse(
      hxd.Res.loader.load(path).toText()
    );
  }
}