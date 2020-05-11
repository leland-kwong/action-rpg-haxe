import h2d.TileGroup;

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

  public function new(s2d: h2d.Scene) {
    var numEntities = 50;

    for (_ in 0...numEntities) {
      var radius = irnd(5, 20);
      var entity = {
        x: rnd(0, s2d.width),
        y: rnd(0, s2d.height),
        radius: radius,
        dx: 0.0,
        dy: 0.0,
        weight: 1.0,
        speed: (5 + Math.floor(20 / radius*2))*30,
      };
      trace(entity.speed, radius);
      ALL.push(entity);

      var graphic = new h2d.Graphics(s2d);
      graphic.x = entity.x;
      graphic.y = entity.y;
      // make outline
      graphic.beginFill(0xFFFFFF);
      graphic.drawCircle(0, 0, entity.radius + 1);
      graphic.beginFill(0xFFF);
      graphic.drawCircle(0, 0, entity.radius);
      graphic.endFill();
      SPRITES.push(graphic);
    }
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    var target = {x: s2d.mouseX, y: s2d.mouseY};

    for( i in 0...ALL.length ) {
      var e = ALL[i];
      var max = e.speed*dt;
      var d_from_target = distance(e.x, e.y, target.x, target.y);
      var threshold = 100;
      var dx = 0.0;
      var dy = 0.0;
      // move towards target
      if (d_from_target > threshold) {
        var aToTarget = Math.atan2(target.y-e.y, target.x-e.x);
        dx += Math.cos(aToTarget)*e.speed*dt;
        dy += Math.sin(aToTarget)*e.speed*dt;
      }
      // if too close to target, move away
      else {
        var aToTarget = Math.atan2(target.y-e.y, target.x-e.x);
        var conflict = threshold - d_from_target;
        dx -= Math.cos(aToTarget)*conflict;
        dy -= Math.sin(aToTarget)*conflict;
      }

      // make entities avoid each other by repulsion
      for (o in ALL) {
        if (o != e) {
          var pt = o;
          var ept = e;
          var d = distance(pt.x, pt.y, ept.x, ept.y);
          var sep = 30;
          var min = pt.radius+ept.radius+sep;
          var isColliding = d < min;
          if (isColliding) {
            var conflict = (min - d);
            var a = Math.atan2(ept.y-pt.y, ept.x-pt.x);
            var w = pt.weight / (pt.weight+e.weight);
            var ew = e.weight / (pt.weight+e.weight);
            dx += Math.cos(a)*(conflict)*ew;
            dy += Math.sin(a)*(conflict)*ew;
            pt.dx -= Math.cos(a)*(conflict)*w;
            pt.dy -= Math.sin(a)*(conflict)*w;
          }
        }
      }

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
      e.x += dx;
      e.y += dy;
      SPRITES[i].x = e.x;
      SPRITES[i].y = e.y;
    }
  }
}