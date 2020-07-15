// [easing algorithms](https://easings.net/) 
import Game.Colors;

class Easing {
  static var pow = Math.pow;
  static var sin = Math.sin;
  static var sqrt = Math.sqrt;
  static var PI = Math.PI;

  public static function easeIn(x: Float): Float {
    return x;
  }

  public static function easeInCirc(x: Float): Float {
    return 1 - sqrt(1 - pow(x, 2));
  }

  public static function easeInOut(x: Float): Float {
    if (x < 0.5) {
      return x;
    }

    return 0.5 - (x - 0.5);
  }

  public static function easeInQuint(x: Float): Float {
    return x * x * x * x * x;
  }

  public static function easeOutQuint(x: Float): Float {
    return 1 - pow(1 - x, 5);
  }

  public static function easeInOutElastic(x: Float): Float {
    var c5 = (2 * Math.PI) / 4.5;

    return x == 0
    ? 0
    : x == 1
    ? 1
    : x < 0.5
    ? -(pow(2, 20 * x - 10) * sin((20 * x - 11.125) * c5)) / 2
    : (pow(2, -20 * x + 10) * sin((20 * x - 11.125) * c5)) / 2 + 1;
  }

  public static function easeInOutQuart(x: Float): Float {
    return x < 0.5 ? 8 * x * x * x * x : 1 - pow(-2 * x + 2, 4) / 2;
  }


  public static function easeInBack(x: Float): Float {
    final c1 = 1.70158;
    final c3 = c1 + 1;

    return c3 * x * x * x - c1 * x * x;
  }

  public static function easeInOutBack(x: Float): Float {
    final c1 = 1.70158;
    final c2 = c1 * 1.525;

    return x < 0.5
      ? (pow(2 * x, 2) * ((c2 + 1) * 2 * x - c2)) / 2
      : (pow(2 * x - 2, 2) * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2;
  }

  public static function easeOutBounce(x: Float) {
    var n1 = 7.5625;
    var d1 = 2.75;

    if (x < 1 / d1) {
      return n1 * x * x;
    } else if (x < 2 / d1) {
      return n1 * (x -= 1.5 / d1) * x + 0.75;
    } else if (x < 2.5 / d1) {
      return n1 * (x -= 2.25 / d1) * x + 0.9375;
    } else {
      return n1 * (x -= 2.625 / d1) * x + 0.984375;
    }
  }

  public static function easeInOutBounce(x: Float) {
    return x < 0.5
    ? (1 - easeOutBounce(1 - 2 * x)) / 2
    : (1 + easeOutBounce(2 * x - 1)) / 2;
  }

  public static function easeHeartBeat(x: Float) {
    return pow(sin(x * PI),12);
  }

  public static function progress(startTime: Float, currentTime: Float, duration: Float) {
    return Math.min(1, (currentTime - startTime) / duration);
  }
}

class EasingExample {
  var g: h2d.Graphics;
  var startTime: Float;
  var duration = 0.5;
  var originalY: Float;
  var time = 0.0;

  public function new(s2d: h2d.Scene) {
    g = new h2d.Graphics(s2d);
    g.beginFill(Colors.yellow);
    g.drawCircle(0, 0, 40);
    g.endFill();
    g.x = s2d.width / 2;
    g.y = s2d.height / 2;
    originalY = g.y;
    startTime = 0.0;
  }

  public function update(dt: Float) {
    time += dt;

    var progress = Easing.progress(startTime, time, duration);
    var v = Easing.easeInQuint(progress);

    // loop
    if (progress == 1) {
      startTime = time;
    }

    g.setScale(1 - v);
  }
}
