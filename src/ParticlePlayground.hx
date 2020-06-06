import h2d.SpriteBatch;
import Game.Cooldown;

typedef Particle = {
  var dx: Float;
  var dy: Float;
  var x: Float;
  var y: Float;
  var speed: Float;
  var lifeTime: Float;
  var createdAt: Float;
  var batchElement: BatchElement;
}

class ParticleSystem {
  public static var particles: Array<Particle> = [];
  public static var batch: h2d.SpriteBatch;
  public static var spriteSheet: h2d.Tile;
  public static var debugText: h2d.Text;
  static var time = 0.0;

  static public function init() {
    spriteSheet = hxd.Res.sprites.shapes.toTile();
    batch = new h2d.SpriteBatch(
      spriteSheet,
      Main.Global.rootScene
    );
    // var outlineFilter = new h2d.filter.Outline(1, Game.Colors.pureWhite);
    // batch.filter = outlineFilter;
    batch.hasRotationScale = true;

    debugText = new h2d.Text(Fonts.primary.get(), Main.Global.rootScene);
    debugText.textColor = Game.Colors.pureWhite;
    debugText.x = 10;
    debugText.y = 10;
  }

  static public function emit(config: Particle) {
    particles.push(config);
    batch.add(config.batchElement);
  }

  static public function update(dt: Float) {
    time += dt;

    debugText.text = 'particles: ${particles.length}';

    // batch.clear();
    {
      var i = 0;
      while (i < particles.length) {
        var p = particles[i];
        var aliveTime = time - p.createdAt;
        // clear old particles
        if (aliveTime >= p.lifeTime) {
          particles.splice(i, 1);
          p.batchElement.remove();

        // update particle
        } else {
          i += 1;

          p.x += p.dx * p.speed * dt;
          p.y += p.dy * p.speed * dt;
          var aliveTime = time - p.createdAt;
          var progress = (aliveTime / p.lifeTime);
          var alpha = p.lifeTime - progress;
          p.batchElement.x = p.x;
          p.batchElement.y = p.y;
          p.batchElement.alpha = alpha;
        }
      }
    }
  }
}

class ParticlePlayground {
  var cds = new Cooldown();
  var emit = (e: hxd.Event = null) -> null;
  var projectileList = [];
  var time = 0.0;
  var tile: h2d.Tile;

  public function new() {
    ParticleSystem.init();

    var rootScene = Main.Global.rootScene;
    tile = ParticleSystem.spriteSheet.sub(0, 0, 16, 16).center();
    emit = (e: hxd.Event = null) -> {
      if (e != null && e.kind != hxd.Event.EventKind.EPush) {
        return;
      }

      var projectile = null;
      {
        var x = 0.0;
        var y = 0.0;
        var angle = Math.atan2(
          rootScene.mouseY - x,
          rootScene.mouseX - y
        );
        var g = new h2d.Bitmap(tile, Main.Global.rootScene);
        projectile = {
          dx: Math.cos(angle),
          dy: Math.sin(angle),
          x: x,
          y: y,
          lifeTime: 0.5,
          speed: 1000,
          startTime: time,
          graphic: g,
          direction: angle
        };
        projectileList.push(projectile);
      }
      return;
    }
  }


  public function remove() {
    ParticleSystem.particles = [];
    ParticleSystem.batch.remove();
    ParticleSystem.debugText.remove();
  }

  public function update(dt) {
    time += dt;
    cds.update(dt);

    if (!cds.has('makeProjectile') && Main.Global.mouse.buttonDown == 0) {
      cds.set('makeProjectile', 1 / 10);
      emit();
    }

    var shouldEmitParticle = !cds.has('emitParticle');
    if (shouldEmitParticle) {
      var projectileSpeed = 1000;
      var emissionRate =  1 / projectileSpeed * 10;
      cds.set('emitParticle', emissionRate);
    }

    var i = 0;
    while (i < projectileList.length) {
      var p = projectileList[i];
      if (time - p.startTime >= p.lifeTime) {
        p.graphic.remove();
        projectileList.splice(i, 1);
      }
      else {
        i += 1;

        p.x += p.dx * p.speed * dt;
        p.y += p.dy * p.speed * dt;
        p.graphic.x = p.x;
        p.graphic.y = p.y;

        if (shouldEmitParticle) {
          var rootScene = Main.Global.rootScene;
          var count = 1;
          var startAngle = Math.atan2(
            rootScene.mouseY - 0,
            rootScene.mouseX - 0
          );
          var angleDiff = Math.PI / 4;
          for (_ in 0...count) {
            // var t = Utils.irnd(0, 1) == 0
            //   ? tile : tile2;
            var batchElement = new BatchElement(tile);
            batchElement.rotation = Utils.rnd(0, 2) * Math.PI;
            var particleConfig = {
              dx: Math.cos(startAngle + Utils.rnd(-angleDiff, angleDiff, true)) * 2,
              dy: Math.sin(startAngle + Utils.rnd(-angleDiff, angleDiff, true)) * 2,
              // dy: 5 * Math.sin(Utils.rnd(angle1, angle2, true)),
              x: p.x,
              y: p.y,
              speed: (p.speed * 0.1 * Math.random()),
              lifeTime: 0.4,
              createdAt: time,
              batchElement: batchElement,
            };
            if (Utils.irnd(0, 1) == 0) {
              batchElement.g = 0.3;
              batchElement.b = 0.1;
            }
            else {
              batchElement.r = 0.3;
              batchElement.g = 0.6;
            }
            ParticleSystem.emit(particleConfig);
          }
        }
      }
    }

    ParticleSystem.update(dt);
  }
}