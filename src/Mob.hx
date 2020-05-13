typedef Point = {
  var id: Int;
  var x : Float;
  var y : Float;
  var radius: Int;
  var dx : Float;
  var dy : Float;
  var weight: Float;
  var speed: Int;
  var color: Int;
}

class Mob {
  public static var ALL: Array<Point> = [];

  var SPRITES: Map<Int, h2d.Graphics> = new Map();

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
    var colors = [
      2 => 0xEF476F,
      3 => 0xF78C6B,
      4 => 0xE9C46A,
      5 => 0x999999,
    ];
    for (index in 0...numEntities) {
      var size = irnd(2, 4);
      var radius = size * 2;
      var speed = (5 + Math.floor(14 / radius*2))*25;
      var entity = {
        id: index,
        x: rnd(0, s2d.width),
        y: rnd(0, s2d.height),
        radius: radius,
        dx: 0.0,
        dy: 0.0,
        weight: 1.0,
        speed: speed,
        color: size,
      };
      ALL.push(entity);
    }

    function obstacle(id, x, y) {
      return {
        id: id,
        x: x,
        y: y,
        radius: 20,
        dx: 0.0,
        dy: 0.0,
        weight: 1.0,
        speed: 0,
        color: 5,
      };
    }
    ALL.push(obstacle(99999, 200.0, 300.0));
    ALL.push(obstacle(99999 + 1, s2d.width / 2, s2d.height / 2));

    for (entity in ALL) {
      var graphic = new h2d.Graphics(s2d);
      graphic.x = entity.x;
      graphic.y = entity.y;
      // make outline
      graphic.beginFill(0x000000);
      graphic.drawCircle(0, 0, entity.radius + 1);
      graphic.beginFill(colors[entity.color]);
      graphic.drawCircle(0, 0, entity.radius);
      graphic.endFill();
      SPRITES[entity.id] = graphic;
    }
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    createGarbage();

    var target = {x: s2d.mouseX, y: s2d.mouseY};
    // distance to keep from destination
    var threshold = 100;

    function byClosest(a, b) {
      var da = distance(a.x, a.y, target.x, target.y);
      var db = distance(b.x, b.y, target.x, target.y);

      if (da < db) {
        return -1;
      }

      if (da > db) {
        return 1;
      }

      return 0;
    }
    /**
      Sort by distance so that the agents closest to the target
      adjust their positions during collision avoidance before
      other entities do. This prevents inner agents from being
      scrunched together due to all the outer agents adding all
      their forces as a domino effect towards the inner agents.
    **/
    ALL.sort(byClosest);

    // reset deltas
    for (a in ALL) {
      a.dx = 0;
      a.dy = 0;
    }

    for( i in 0...ALL.length ) {
      var e = ALL[i];
      var dFromTarget = distance(e.x, e.y, target.x, target.y);
      var dx = e.dx;
      var dy = e.dy;
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
        dx -= Math.cos(aToTarget) * conflict * Math.max(0.05, speedAdjust);
        dy -= Math.sin(aToTarget) * conflict * Math.max(0.05, speedAdjust);
      }

      // make entities avoid each other by repulsion
      for (o in ALL) {
        if (o != e) {
          var pt = e;
          var ept = o;
          var d = distance(pt.x, pt.y, ept.x, ept.y);
          var separation = pt.radius + 4;
          var min = pt.radius + ept.radius + separation;
          var isColliding = d < min;
          if (isColliding) {
            var conflict = Math.min(2, (min - d) * 40 / speed);
            var a = Math.atan2(ept.y - pt.y, ept.x - pt.x);
            var w = pt.weight / (pt.weight + ept.weight);
            var ew = ept.weight / (pt.weight + ept.weight);
            var multiplier = ept.speed == 0 ? 4 : 1;
            dx -= Math.cos(a) * conflict * w * multiplier;
            dy -= Math.sin(a) * conflict * w * multiplier;
            ept.dx += Math.cos(a) * conflict * ew;
            ept.dy += Math.sin(a) * conflict * ew;
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
      var id = e.id;
      SPRITES[id].x = e.x;
      SPRITES[id].y = e.y;
    }
  }
}