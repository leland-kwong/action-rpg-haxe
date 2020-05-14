typedef Point = {
  var id: Int;
  var x : Float;
  var y : Float;
  var radius: Int;
  var dx : Float;
  var dy : Float;
  var weight: Float;
  var speed: Float;
  var color: Int;
  var avoidOthers: Bool;
  var forceMultiplier: Float;
}

class Mob {
  public static var ALL: Array<Point> = [];

  var SPRITES: Map<Int, h2d.Graphics> = new Map();
  var player: Point;
  var target: h2d.Object;
  var TARGET_RADIUS = 20.0;
  var targetSprite: h2d.Graphics;

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
    var numEntities = 500;
    var colors = [
      2 => 0xF78C6B,
      3 => 0xFFD166,
      4 => 0x06D6A0,
      5 => 0x999999,
      6 => 0x118AB2,
    ];

    target = new h2d.Object(s2d);
    targetSprite = new h2d.Graphics(target);
    targetSprite.beginFill(0xffffff, 0.3);
    targetSprite.drawCircle(0, 0, TARGET_RADIUS);

    function makeId() {
      return Std.random(9999999);
    }

    for (_ in 0...numEntities) {
      var size = irnd(2, 4);
      var radius = size * 2;
      var speed = (5 + 2 / radius * 500) * 1.4;
      var entity = {
        id: makeId(),
        x: s2d.width * 0.5,
        y: s2d.height * 0.5,
        radius: radius,
        dx: 0.0,
        dy: 0.0,
        weight: 1.0,
        speed: speed,
        color: colors[size],
        avoidOthers: true,
        forceMultiplier: 1.0,
      };
      ALL.push(entity);
    }

    function obstacle(x, y) {
      return {
        id: makeId(),
        x: x,
        y: y,
        radius: 20,
        dx: 0.0,
        dy: 0.0,
        weight: 1.0,
        speed: 0.0,
        color: colors[5],
        avoidOthers: false,
        forceMultiplier: 3.0,
      };
    }
    ALL.push(obstacle(200.0, 300.0));
    ALL.push(obstacle(s2d.width / 2, s2d.height / 2));

    player = {
      id: makeId(),
      x: 0.0,
      y: 0.0,
      radius: 25,
      dx: 0.0,
      dy: 0.0,
      weight: 1.0,
      speed: 500.0,
      color: colors[6],
      avoidOthers: false,
      forceMultiplier: 3.0,
    }
    ALL.push(player);

    for (entity in ALL) {
      var graphic = new h2d.Graphics(s2d);
      graphic.x = entity.x;
      graphic.y = entity.y;
      // make outline
      graphic.beginFill(0x000000);
      graphic.drawCircle(0, 0, entity.radius + 1);
      graphic.beginFill(entity.color);
      graphic.drawCircle(0, 0, entity.radius);
      graphic.endFill();
      SPRITES[entity.id] = graphic;
    }
  }

  function agentCollide(agents: Array<Point>, sprites: Map<Int, h2d.Graphics>, target: h2d.Object, TARGET_RADIUS) {
    for (a in agents) {
      var s = sprites[a.id];
      s.color.set(1, 1, 1);

      var d = distance(target.x, target.y, a.x, a.y);
      var min = TARGET_RADIUS + a.radius * 1.0;
      var isConflict = d < min;
      if (isConflict) {
        s.color.set(255, 255, 255);
      }
    }
  }

  function movePlayer(player: Point, dt: Float, s2d: h2d.Scene) {
    var Key = hxd.Key;
    var dx = 0;
    var dy = 0;

    if (Key.isDown(Key.A)) {
      dx = -1;
    }
    if (Key.isDown(Key.D)) {
      dx = 1;
    }
    if (Key.isDown(Key.W)) {
      dy = -1;
    }
    if (Key.isDown(Key.S)) {
      dy = 1;
    }

    var magnitude = Math.sqrt(dx * dx + dy * dy);
    var dxNormalized = magnitude == 0 ? dx : dx / magnitude;
    var dyNormalized = magnitude == 0 ? dy : dy / magnitude;

    player.x += dxNormalized * player.speed * dt;
    player.y += dyNormalized * player.speed * dt;
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    movePlayer(player, dt, s2d);
    agentCollide(ALL, SPRITES, target, TARGET_RADIUS);

    target.x = s2d.mouseX;
    target.y = s2d.mouseY;

    var follow = player;

    // distance to keep from destination
    var threshold = player.radius + 30;

    function byClosest(a, b) {
      var da = distance(a.x, a.y, follow.x, follow.y);
      var db = distance(b.x, b.y, follow.x, follow.y);

      if (da < db) {
        return -1;
      }

      if (da > db) {
        return 1;
      }

      return 0;
    }
    /**
      Sort by closest to furtherst so that repelling forces go
      from inside to outside to prevent inner agents from getting
      scrunched up.
    **/
    ALL.sort(byClosest);

    // reset deltas
    for (a in ALL) {
      a.dx = 0;
      a.dy = 0;
    }

    for(i in 0...ALL.length) {
      var e = ALL[i];
      var dFromTarget = distance(e.x, e.y, follow.x, follow.y);
      var dx = e.dx;
      var dy = e.dy;
      // exponential drop-off as agent approaches destination
      var speedAdjust = Math.max(0,
                                 Math.min(1,
                                          Math.pow((dFromTarget - threshold) / threshold, 4)));
      var speed = e.speed;
      if (dFromTarget > threshold) {
        var aToTarget = Math.atan2(follow.y - e.y, follow.x - e.x);
        dx += Math.cos(aToTarget) * speedAdjust;
        dy += Math.sin(aToTarget) * speedAdjust;
      }

      if (e.avoidOthers) {
        // make entities avoid each other by repulsion
        for (o in ALL) {
          if (o != e) {
            var pt = e;
            var ept = o;
            var d = distance(pt.x, pt.y, ept.x, ept.y);
            var separation = pt.radius + 10 + Math.sqrt(speed / 2);
            var min = pt.radius + ept.radius + separation;
            var isColliding = d < min;
            if (isColliding) {
              var conflict = min - d;
              var adjustedConflict = Math.min(conflict, conflict * 50 / speed);
              var a = Math.atan2(ept.y - pt.y, ept.x - pt.x);
              var w = pt.weight / (pt.weight + ept.weight);
              // immobile entities have a stronger influence (obstacles such as walls, etc...)
              var multiplier = ept.forceMultiplier;
              var avoidX = Math.cos(a) * adjustedConflict * w * multiplier;
              var avoidY = Math.sin(a) * adjustedConflict * w * multiplier;

              if (avoidX == 0) {
                avoidX = 0.001;
              }

              if (avoidY == 0) {
                avoidY = 0.001;
              }

              dx -= avoidX;
              dy -= avoidY;
            }
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