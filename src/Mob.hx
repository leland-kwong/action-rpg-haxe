typedef Point = {
  var x : Float;
  var y : Float;
  var radius: Int;
  var dx : Float;
  var dy : Float;
  var weight: Float;
  var speed: Int;
}

class Mob {
  public static var ALL: Array<Point> = [];

  var SPRITES: Array<h2d.Graphics> = [];

  function rnd(min:Float, max:Float, ?sign=false) {
    if( sign )
      return (min + Math.random()*(max-min)) * (Std.random(2)*2-1);
    else
      return min + Math.random()*(max-min);
  }

  function irnd(min:Int, max:Int, ?sign:Bool) {
    if( sign )
      return (min + Std.random(max-min+1)) * (Std.random(2)*2-1);
    else
      return min + Std.random(max-min+1);
  }

  function distanceSqr(ax:Float,ay:Float,bx:Float,by:Float) : Float {
    return (ax-bx)*(ax-bx) + (ay-by)*(ay-by);
  }

  function distance(ax:Float,ay:Float, bx:Float,by:Float) : Float {
    return Math.sqrt( distanceSqr(ax,ay,bx,by) );
  }

  function createGarbage() {
    var tempList: Array<Dynamic> = [];

    for (_ in 0...3000) {
      tempList.push({
        x: 0,
        y: 0,
      });
    }
  }

  public function new(s2d: h2d.Scene) {
    var numEntities = 500;

    for (_ in 0...numEntities) {
      var radius = irnd(2, 4) * 2;
      var entity = {
        x: rnd(0, s2d.width),
        y: rnd(0, s2d.height),
        radius: radius,
        dx: 0.0,
        dy: 0.0,
        weight: 1.0,
        speed: (5 + Math.floor(14 / radius*2))*15,
      };
      ALL.push(entity);

      var graphic = new h2d.Graphics(s2d);
      graphic.x = entity.x;
      graphic.y = entity.y;
      // make outline
      graphic.beginFill(0x000000);
      graphic.drawCircle(0, 0, entity.radius + 1);
      graphic.beginFill(0xc767c4);
      graphic.drawCircle(0, 0, entity.radius);
      graphic.endFill();
      SPRITES.push(graphic);
    }
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    createGarbage();

    var target = {x: s2d.mouseX, y: s2d.mouseY};
    // distance to keep from destination
    var threshold = 50;

    for( i in 0...ALL.length ) {
      var e = ALL[i];
      var dFromTarget = distance(e.x, e.y, target.x, target.y);
      var dx = 0.0;
      var dy = 0.0;
      // exponential drop-off as agent approaches destination
      var speedAdjust = Math.max(0,
                                 Math.min(1,
                                          Math.pow((dFromTarget - (threshold / 2)) / threshold, 2)));
      var speed = e.speed;
      if (dFromTarget > threshold) {
        var aToTarget = Math.atan2(target.y - e.y, target.x - e.x);
        dx += Math.cos(aToTarget) * speedAdjust;
        dy += Math.sin(aToTarget) * speedAdjust;
      }
      // if too close to target, push everything away (we can use this for things like aoe knockback)
      if (dFromTarget < threshold) {
        var aToTarget = Math.atan2(target.y - e.y, target.x - e.x);
        var conflict = threshold - dFromTarget;
        dx -= Math.cos(aToTarget) * conflict * 0.5;
        dy -= Math.sin(aToTarget) * conflict * 0.5;
      }

      // make entities avoid each other by repulsion
      for (o in ALL) {
        if (o != e) {
          var pt = e;
          var ept = o;
          var d = distance(pt.x, pt.y, ept.x, ept.y);
          var sep = 10 + pt.radius * 2;
          var min = pt.radius + ept.radius + sep;
          var isColliding = d < min;
          if (isColliding) {
            var conflict = (min - d) * 0.5;
            var a = Math.atan2(ept.y - pt.y, ept.x - pt.x);
            var w = pt.weight / (pt.weight + e.weight);
            var ew = e.weight / (pt.weight + e.weight);
            dx -= Math.cos(a) * conflict * ew * speedAdjust;
            dy -= Math.sin(a) * conflict * ew * speedAdjust;
            ept.dx -= Math.cos(a) * conflict * w * speedAdjust;
            ept.dy -= Math.sin(a) * conflict * w * speedAdjust;
          }
        }
      }

      var max = 1;
      if (dx > max) {
        dx = max;
      }
      if (dx < -max) {
        dx = -max;
      }
      if (dy > max) {
        dy = max;
      }
      if (dy < -max) {
        dy = -max;
      }
      e.x += dx * speed * dt;
      e.y += dy * speed * dt;
      SPRITES[i].x = e.x;
      SPRITES[i].y = e.y;
    }
  }
}