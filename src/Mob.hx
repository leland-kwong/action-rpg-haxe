using hxd.Event;
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
  var color: Int;
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
  public var type: String;
  public var radius: Int;
  public var dx = 0.0;
  public var dy = 0.0;
  public var weight = 1.0;
  public var speed = 0.0;
  public var color: Int;
  public var avoidOthers = false;
  public var forceMultiplier = 1.0;
  public var health = 1;
  public var damageTaken = 0;

  public function new(props: Point) {
    super();

    x = props.x;
    y = props.y;
    id = idGenerated++;
    radius = props.radius;
    weight = props.weight;
    color = props.color;

    ALL.push(this);
  }

  public function update(dt: Float) {
    if (speed != 0) {
      var max = 1;

      if (dx != 0) {
        if (dx > max) {
          dx = max;
        }
        if (dx < -max) {
          dx = -max;
        }
        x += dx * speed * dt;
      }

      if (dy != 0) {
        if (dy > max) {
          dy = max;
        }
        if (dy < -max) {
          dy = -max;
        }
        y += dy * speed * dt;
      }
    }
  }

  public function findNearest(x, y, range, filter: String) {
    var item = null;
    var prevDist = 999999.0;

    for (e in ALL) {
      if (e != this && e.type == filter) {
        var d = Utils.distance(x, y, e.x, e.y);
        if (d <= range && d < prevDist) {
          item = e;
          prevDist = d;
        }
      }
    }

    return item;
  }
}

class Bullet extends Entity {
  var damage = 1;
  var lifeTime = 5.0;

  public function new(x1: Float, y1: Float, x2: Float, y2: Float) {
    super({
      x: x1,
      y: y1,
      radius: 10,
      color: 0xffffff,
      weight: 0.0,
    });
    speed = 500.0;
    forceMultiplier = 0.0;

    var sprite = new h2d.Graphics();
    addChild(sprite);

    sprite.beginFill(0xFFFFFF);
    sprite.drawCircle(0, 0, radius);
    sprite.endFill();

    var aToTarget = Math.atan2(y2 - y1, x2 - x1);
    var _dx = Math.cos(aToTarget);
    var _dy = Math.sin(aToTarget);
    var magnitude = Math.sqrt(_dx * _dx + _dy * _dy);
    var dxNormalized = magnitude == 0 ? _dx : _dx / magnitude;
    var dyNormalized = magnitude == 0 ? _dy : _dy / magnitude;
    dx = dxNormalized;
    dy = dyNormalized;
  }

  public override function update(dt: Float) {
    super.update(dt);

    lifeTime -= dt;

    if (lifeTime <= 0) {
      health = 0;
    }

    for (a in Entity.ALL) {
      if (a.type == 'ENEMY') {
        var d = Utils.distance(x, y, a.x, a.y);
        var min = radius + a.radius * 1.0;
        var isConflict = d < min;
        if (isConflict) {
          health = 0;
          a.damageTaken += damage;
          break;
        }
      }
    }
  }
}

class Turret extends Entity {
  var cds: Cooldown;
  var range = 300;
  var lifeTime = 10.0;

  public function new(x, y) {
    super({
      x: x,
      y: y,
      radius: 20,
      color: 0xff6392,
      weight: 0.0,
    });
    health = 100;
    cds = new Cooldown();

    var sprite = new h2d.Graphics(this);
    sprite.beginFill(color);
    sprite.drawCircle(0, 0, radius);
    sprite.endFill();
  }

  public override function update(dt: Float) {
    super.update(dt);

    cds.update(dt);

    if (!cds.has('attack')) {
      cds.set('attack', 0.2);

      var nearest = findNearest(x, y, range, 'ENEMY');
      if (nearest != null) {
        var b = new Bullet(x, y, nearest.x, nearest.y);
        parent.addChild(b);
      }
    }

    lifeTime -= dt;
    var isDisposed = lifeTime <= 0;
    if (isDisposed) {
      health = 0;
    }
  }
}

class Enemy extends Entity {
  static var healthBySize = [
    1 => 5,
    2 => 10,
    3 => 20,
  ];
  static var speedBySize = [
    1 => 350.0,
    2 => 200.0,
    3 => 150.0,
  ];

  var font: h2d.Font = hxd.res.DefaultFont.get().clone();
  var text: h2d.Text;
  var cds: Cooldown;
  var damage = 1;
  public var attackTarget: Entity;

  public function new(props, size) {
    super(props);
    type = 'ENEMY';
    speed = speedBySize[size];
    health = healthBySize[size];
    avoidOthers = true;
    cds = new Cooldown();

    cds.set('summoningSickness', 1.0);

    var graphic = new h2d.Graphics(this);
    // make outline
    graphic.beginFill(0x000000);
    graphic.drawCircle(0, 0, radius + 1);
    graphic.beginFill(color);
    graphic.drawCircle(0, 0, radius);
    graphic.endFill();

    font.resizeTo(20);
    text = new h2d.Text(font);
    text.textAlign = Center;
    text.textColor = 0x000000;
    // vertical align center
    text.y = -text.textHeight / 2;
    addChild(text);
  }

  public override function update(dt) {
    super.update(dt);

    cds.update(dt);
    text.text = '${health}';

    if (!cds.has('summoningSickness') && attackTarget != null) {
      if (!cds.has('attack')) {
        cds.set('attack', 1.0);
        attackTarget.health -= damage;
      }
    }

    for (child in iterator()) {
      var c:Dynamic = child;

      if (Type.getClass(child) == h2d.Graphics) {
        if (!cds.has('hitFlash')) {
          c.color.set(1, 1, 1, 1);
        }

        if (damageTaken > 0) {
          cds.set('hitFlash', 0.04);
          c.color.set(255, 255, 255, 1);
          health -= damageTaken;
          damageTaken = 0;
        }
      }
    }

    attackTarget = null;
  }
}

class Player extends Entity {
  var text: h2d.Text;

  public function new(x, y) {
    super({
      x: x,
      y: y,
      radius: 25,
      weight: 1.0,
      color: 0x118AB2,
    });
    health = 10;
    speed = 500.0;
    forceMultiplier = 3.0;

    var playerSprite = new h2d.Graphics(this);
    // make outline
    playerSprite.beginFill(0xffffff);
    playerSprite.drawCircle(0, 0, radius + 2);
    playerSprite.beginFill(color);
    playerSprite.drawCircle(0, 0, radius);
    playerSprite.endFill();

    var font: h2d.Font = hxd.res.DefaultFont.get().clone();
    font.resizeTo(16);
    text = new h2d.Text(font);
    text.textAlign = Center;
    text.textColor = 0xffffff;
    // vertical align center
    text.y = -text.textHeight / 2;
    addChild(text);
  }

  public override function update(dt) {
    super.update(dt);

    text.text = '${health}';
  }
}

class Mob {
  var player: Entity;
  var target: h2d.Object;
  var TARGET_RADIUS = 20.0;
  var targetSprite: h2d.Graphics;
  var useAbilityOnClick: (ev: hxd.Event) -> Void;

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

  public function isGameOver() {
    return player.health <= 0;
  }

  public function cleanup() {
    // reset game state
    for (e in Entity.ALL) {
      e.health = 0;
    }

    target.remove();
    hxd.Window.getInstance()
      .removeEventTarget(useAbilityOnClick);
  }

  public function newLevel(s2d: h2d.Scene, level: Int) {
    var numEnemies = level * Math.round(level /2);
    var colors = [
      1 => 0xF78C6B,
      2 => 0xFFD166,
      3 => 0x06D6A0,
    ];

    /* TODO:
      Spawn enemies in over time. This way they don't all
      show up at once and clog.
    */
    for (_ in 0...numEnemies) {
      var size = irnd(1, 3);
      var radius = size * 20;
      var e = new Enemy({
        x: s2d.width * 0.5,
        y: s2d.height * 0.5,
        radius: radius,
        weight: 1.0,
        color: colors[size],
      }, size);
      s2d.addChild(e);
    }
  }

  public function new(
    s2d: h2d.Scene,
    oldGame: Mob
  ) {
    if (oldGame != null) {
      oldGame.cleanup();
    }
    player = new Player(s2d.width / 2, s2d.height / 2);
    s2d.addChild(player);

    // mouse pointer
    target = new h2d.Object(s2d);
    targetSprite = new h2d.Graphics(target);
    targetSprite.beginFill(0xffda3d, 0.3);
    targetSprite.drawCircle(0, 0, TARGET_RADIUS);

    useAbilityOnClick = function(ev: hxd.Event) {
      if (ev.kind == hxd.EventKind.EPush) {
        useAbility(ev.relX, ev.relY, s2d);
        // trace(ev.toString());
      }
    }
    hxd.Window.getInstance()
      .addEventTarget(useAbilityOnClick);
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

  function useAbility(x1, y1, s2d: h2d.Scene) {
    var turret = new Turret(x1, y1);
    s2d.addChild(turret);
  }

  public function update(s2d: h2d.Scene, dt: Float) {
    var ALL = Entity.ALL;

    // cleanup/update agents first
    {
      var i = 0;
      while (i < ALL.length) {
        var a = ALL[i];
        var isDisposed = a.health <= 0;
        if (isDisposed) {
          ALL.splice(i, 1);
          a.remove();
        } else {
          a.update(dt);
          i += 1;
        }
      }
    }

    movePlayer(player, dt, s2d);

    target.x = s2d.mouseX;
    target.y = s2d.mouseY;

    var follow = player;

    // distance to keep from destination
    var threshold = player.radius + 30;
    var attackRange = threshold + 100;

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

    function updateEnemies(list: Array<Entity>) {
      for(e in list) {
        if (!Std.is(e, Enemy)) {
          continue;
        }

        var dFromTarget = Utils.distance(e.x, e.y, follow.x, follow.y);
        var dx = 0.0;
        var dy = 0.0;
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

        if (dFromTarget <= attackRange) {
          Reflect.setField(e, 'attackTarget', player);
        }

        if (e.avoidOthers) {
          // make entities avoid each other by repulsion
          for (o in ALL) {
            if (o != e && o.forceMultiplier > 0) {
              var pt = e;
              var ept = o;
              var d = Utils.distance(pt.x, pt.y, ept.x, ept.y);
              var separation = 5 + Math.sqrt(speed / 2);
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

    updateEnemies(ALL);
  }
}