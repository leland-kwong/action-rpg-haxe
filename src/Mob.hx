class Utils {
  public static function distanceSqr(ax:Float,ay:Float,bx:Float,by:Float) : Float {
    return (ax-bx)*(ax-bx) + (ay-by)*(ay-by);
  }

  public static function distance(ax:Float,ay:Float, bx:Float,by:Float) : Float {
    return Math.sqrt( distanceSqr(ax,ay,bx,by) );
  }
}
typedef Point = {
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

class Cooldown {
  var cds: Map<String, Float>;

  public function new() {
    cds = new Map();
  }

  public function set(key, value) {
    cds[key] = value;
  }

  public function has(key) {
    return cds.exists(key) && cds[key] > 0.0;
  }

  public function update(dt: Float) {
    for (key => value in cds) {
      cds[key] = value - dt;
    }
  }
}

class Entity extends h2d.Object {
  static var idGenerated = 0;

  public static var ALL: Array<Entity> = [];
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
  public var hovered = false;

  public function new(props: Point) {
    super();

    x = props.x;
    y = props.y;
    id = idGenerated++;
    radius = props.radius;
    weight = props.weight;
    speed = props.speed;
    color = props.color;
    avoidOthers = props.avoidOthers;
    forceMultiplier = props.forceMultiplier;
    health = props.health;

    ALL.push(this);
  }

  public function update(dt) {
    for (child in iterator()) {
      // NOTE: ask in discord whether theres a more idiomatic way
      // for checking multiple types
      var c:Dynamic = child;

      if (Type.getClass(child) == h2d.Graphics) {
        c.color.set(1, 1, 1);

        if (hovered) {
          c.color.set(255, 255, 255);
        }
      }
    }

    hovered = false;
  }

  public function findNearest(x, y) {
    var item = null;
    var prevDist = 999999.0;

    for (e in ALL) {
      if (e != this) {
        var d = Utils.distance(x, y, e.x, e.y);
        if (d < prevDist) {
          item = e;
          prevDist = d;
        }
      }
    }

    return item;
  }
}

class Bullet extends Entity {
  var damage = 1.0;
  var lifeTime = 1.0;

  public function new(x1, y1, x2, y2) {
    super({
      x: x,
      y: y,
      radius: 10,
      health: 1,
      forceMultiplier: 1.0,
      color: 0xffffff,
      speed: 200.0,
      avoidOthers: false,
      weight: 0.0,
    });

    var magnitude = Math.sqrt(dx * dx + dy * dy);
    var dxNormalized = magnitude == 0 ? dx : dx / magnitude;
    var dyNormalized = magnitude == 0 ? dy : dy / magnitude;
    dx = dxNormalized;
    dy = dyNormalized;
  }

  public override function update(dt: Float) {
    lifeTime -= dt;

    if (lifeTime <= 0) {
      health = 0;
    }
  }
}

class Turret extends Entity {
  var cds: Cooldown;

  public function new(x, y) {
    super({
      x: x,
      y: y,
      radius: 20,
      health: 100,
      forceMultiplier: 1.0,
      color: 0xff6392,
      speed: 0.0,
      avoidOthers: false,
      weight: 0.0,
    });

    cds = new Cooldown();
  }

  public override function update(dt: Float) {
    super.update(dt);

    cds.update(dt);

    if (!cds.has('attack')) {
      cds.set('attack', 1.0);

      var nearest = findNearest(x, y);
      // trace(nearest.x, nearest.y);
      new Bullet(x, y, nearest.x, nearest.y);
    }
  }
}

class Mob {
  var player: Entity;
  var target: h2d.Object;
  var TARGET_RADIUS = 20.0;
  var targetSprite: h2d.Graphics;
  var turret: Turret;

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

  public function new(s2d: h2d.Scene) {
    turret = new Turret(
      250,
      150
    );

    var numEntities = 2;
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

    for (_ in 0...numEntities) {
      var size = irnd(2, 4);
      var radius = size * 2;
      var speed = (5 + 2 / radius * 500) * 1.4;
      new Entity({
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
    }

    function obstacle(x, y) {
      return new Entity({
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
    obstacle(200.0, 300.0);
    obstacle(s2d.width - 100.0, s2d.height / 2);

    player = new Entity({
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

    for (entity in Entity.ALL) {
      var graphic = new h2d.Graphics(entity);
      // make outline
      graphic.beginFill(0x000000);
      graphic.drawCircle(0, 0, entity.radius + 1);
      graphic.beginFill(entity.color);
      graphic.drawCircle(0, 0, entity.radius);
      graphic.endFill();
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
      var d = Utils.distance(target.x, target.y, a.x, a.y);
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
    var ALL = Entity.ALL;

    // cleanup disposed agents first
    {
      var i = 0;
      while (i < ALL.length) {
        var a = ALL[i];
        var isDisposed = a.health <= 0;
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
      a.update(dt);
    }

    movePlayer(player, dt, s2d);

    function onAgentHover(a) {
      a.hovered = true;
    }
    agentCollide(ALL, target, TARGET_RADIUS, onAgentHover);

    target.x = s2d.mouseX;
    target.y = s2d.mouseY;

    var follow = player;

    // distance to keep from destination
    var threshold = player.radius + 30;

    function byClosest(a, b) {
      var da = Utils.distance(a.x, a.y, follow.x, follow.y);
      var db = Utils.distance(b.x, b.y, follow.x, follow.y);

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
      var dFromTarget = Utils.distance(e.x, e.y, follow.x, follow.y);
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
            var d = Utils.distance(pt.x, pt.y, ept.x, ept.y);
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