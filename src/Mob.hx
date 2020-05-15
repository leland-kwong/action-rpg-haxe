typedef Point = {
  var id: Int;
  var x : Float;
  var y : Float;
  var radius: Int;
  var weight: Float;
  var speed: Float;
  var color: Int;
  var avoidOthers: Bool;
  var forceMultiplier: Float;
  var health: Int;
}

class Entity extends h2d.Object {
  public var id: Int;
  public var radius: Int;
  public var dx = 0.0;
  public var dy = 0.0;
  public var weight = 1.0;
  public var speed = 0.0;
  public var color: Int;
  public var avoidOthers = false;
  public var forceMultiplier = 1.0;
  public var health = 1;

  public function new(props: Point) {
    super();

    x = props.x;
    y = props.y;
    id = props.id;
    radius = props.radius;
    weight = props.weight;
    speed = props.speed;
    color = props.color;
    avoidOthers = props.avoidOthers;
    forceMultiplier = props.forceMultiplier;
    health = props.health;
  }
}

class Mob {
  public static var ALL: Array<Entity> = [];

  var SPRITES: Map<Int, h2d.Graphics> = new Map();
  var player: Entity;
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
    var numEntities = 100;
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
      var entity = new Entity({
        id: makeId(),
        x: s2d.width * 0.5,
        y: s2d.height * 0.5,
        radius: radius,
        weight: 1.0,
        speed: speed,
        color: colors[size],
        avoidOthers: true,
        forceMultiplier: 1.0,
        health: 100,
      });
      ALL.push(entity);
    }

    function obstacle(x, y) {
      return new Entity({
        id: makeId(),
        x: x,
        y: y,
        radius: 20,
        weight: 1.0,
        speed: 0.0,
        color: colors[5],
        avoidOthers: false,
        forceMultiplier: 3.0,
        health: 99999,
      });
    }
    ALL.push(obstacle(200.0, 300.0));
    ALL.push(obstacle(s2d.width - 100.0, s2d.height / 2));

    player = new Entity({
      id: makeId(),
      x: s2d.width * 0.5,
      y: s2d.height * 0.5,
      radius: 25,
      weight: 1.0,
      speed: 500.0,
      color: colors[6],
      avoidOthers: false,
      forceMultiplier: 3.0,
      health: 100,
    });
    ALL.push(player);

    for (entity in ALL) {
      var graphic = new h2d.Graphics(entity);
      // make outline
      graphic.beginFill(0x000000);
      graphic.drawCircle(0, 0, entity.radius + 1);
      graphic.beginFill(entity.color);
      graphic.drawCircle(0, 0, entity.radius);
      graphic.endFill();
      SPRITES[entity.id] = graphic;
      s2d.addChild(entity);
    }
  }

  function agentCollide(
    agents: Array<Entity>,
    target: h2d.Object,
    TARGET_RADIUS,
    onCollide: (a: Entity) -> Void
  ) {
    for (a in agents) {
      var d = distance(target.x, target.y, a.x, a.y);
      var min = TARGET_RADIUS + a.radius * 1.0;
      var isConflict = d < min;
      if (isConflict) {
        onCollide(a);
      }
    }
  }

  function movePlayer(player: Entity, dt: Float, s2d: h2d.Scene) {
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
    // cleanup disposed agents first
    {
      var i = 0;
      while (i < ALL.length) {
        var a = ALL[i];
        var isDisposed = a.health == 0;
        if (isDisposed) {
          ALL.splice(i, 1);
          a.remove();
        } else {
          i += 1;
        }
      }
    }

    // reset agent states
    for (a in ALL) {
      var s = SPRITES[a.id];
      s.color.set(1, 1, 1);
    }

    movePlayer(player, dt, s2d);

    function onAgentHover(a) {
      var s = SPRITES[a.id];
      s.color.set(255, 255, 255);
      a.health = 0;
    }
    agentCollide(ALL, target, TARGET_RADIUS, onAgentHover);

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
    }
  }
}