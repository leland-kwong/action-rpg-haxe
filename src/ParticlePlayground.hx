import h2d.SpriteBatch;
import Game.Cooldown;

typedef Particle = {
  var dx: Float;
  var dy: Float;
  var x: Float;
  var y: Float;
  var speed: Float;
  var ?alpha: (p: Particle, progress: Float) -> Float;
  var ?scale: (p: Particle, progress: Float) -> Float;
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
  static var maxParticles = 0;

  static public function init() {
    spriteSheet = hxd.Res.sprites.shapes.toTile();
    batch = new h2d.SpriteBatch(
      spriteSheet,
      Main.Global.rootScene
    );
    batch.hasRotationScale = true;

    debugText = new h2d.Text(Fonts.primary.get(), Main.Global.rootScene);
    debugText.textColor = Game.Colors.pureWhite;
    debugText.x = 10;
    debugText.y = 10;
  }

  static public function emit(config: Particle, before = false) {
    particles.push(config);
    batch.add(config.batchElement, before);
  }

  static public function update(dt: Float) {
    time += dt;

    maxParticles = Math.round(Math.max(maxParticles, particles.length));
    debugText.text = [
      'particles: ${particles.length}',
      'maxParticles: ${maxParticles}'
    ].join('\n');

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
          p.batchElement.x = p.x;
          p.batchElement.y = p.y;
          if (p.alpha != null) {
            p.batchElement.alpha = p.alpha(p, progress);
          }
          if (p.scale != null) {
            p.batchElement.scale = p.scale(p, progress);
          }
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
  var circleTile: h2d.Tile;

  public function new() {
    ParticleSystem.init();

    var rootScene = Main.Global.rootScene;
    tile = ParticleSystem.spriteSheet.sub(0, 0, 16, 16).center();
    circleTile = ParticleSystem.spriteSheet.sub(0, 16, 16, 16).center();
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
        var g = new BatchElement(tile);
        g.rotation = angle;
        projectile = {
          dx: Math.cos(angle),
          dy: Math.sin(angle),
          x: x,
          y: y,
          lifeTime: 0.5,
          speed: 1000.0,
          createdAt: time,
          batchElement: g,
        };
        ParticleSystem.emit(projectile);
        projectileList.push(projectile);

        // muzzle flash
        var batchElement = new BatchElement(circleTile);
        batchElement.scale = 2;
        var particleConfig = {
          dx: 0.0,
          dy: 0.0,
          x: projectile.x,
          y: projectile.y,
          speed: 0.0,
          lifeTime: 0.01,
          createdAt: time,
          batchElement: batchElement,
        };
        ParticleSystem.emit(particleConfig);
      }
      return;
    }
  }


  public function remove() {
    ParticleSystem.particles = [];
    ParticleSystem.batch.clear();
    ParticleSystem.debugText.text = '';
  }

  public function update(dt) {
    time += dt;
    cds.update(dt);

    if (!cds.has('makeProjectile') && Main.Global.mouse.buttonDown == 0) {
      cds.set('makeProjectile', 1 / 20);
      // for (_ in 0...10) {
        emit();
      // }
    }

    var shouldEmitParticle = !cds.has('emitParticle');
    if (shouldEmitParticle) {
      var projectileSpeed = 1000;
      var emissionRate =  1 / projectileSpeed * 40;
      cds.set('emitParticle', emissionRate);
    }

    var i = 0;
    function pAlpha(p, progress: Float) {
      return 1 - progress;
    }

    function pScale(p, progress: Float) {
      return (1 - (progress / 2));
    }

    function projectileHitAlpha(p, progress: Float) {
      return 1 - progress;
    }

    while (i < projectileList.length) {
      var p = projectileList[i];
      // cleanup projectile
      if (time - p.createdAt >= p.lifeTime) {
        projectileList.splice(i, 1);

        for (_ in 0...3) {
          var batchElement = new BatchElement(circleTile);
          var angle = Math.atan2(p.dy, p.dx)
            + Math.PI
            + (Math.PI / 8 * Utils.irnd(-3, 3, true));

          batchElement.scaleX = 1.2;
          batchElement.scaleY = 0.4;
          batchElement.rotation = angle;

          var particleConfig = {
            dx: Math.cos(angle),
            dy: Math.sin(angle),
            x: p.x,
            y: p.y,
            speed: 400.0,
            lifeTime: 0.15,
            alpha: projectileHitAlpha,
            createdAt: time,
            batchElement: batchElement,
          };
          ParticleSystem.emit(particleConfig);
        }
      }
      else {
        i += 1;

        if (shouldEmitParticle) {
          var rootScene = Main.Global.rootScene;
          var count = 2;
          var startAngle = Math.atan2(
            rootScene.mouseY - 0,
            rootScene.mouseX - 0
          );
          var angleDiff = Math.PI / 4;
          for (_ in 0...count) {
            var batchElement = new BatchElement(tile);
            batchElement.scaleY = 0.9;
            batchElement.scaleX = 1.2;
            batchElement.rotation = Utils.rnd(-angleDiff, angleDiff);
            var particleConfig = {
              dx: Math.cos(startAngle + Utils.rnd(-angleDiff, angleDiff, true)) * 2,
              dy: Math.sin(startAngle + Utils.rnd(-angleDiff, angleDiff, true)) * 2,
              x: p.x,
              y: p.y,
              speed: (p.speed * 0.1),
              lifeTime: 0.10,
              createdAt: time,
              alpha: pAlpha,
              scale: pScale,
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
            ParticleSystem.emit(particleConfig, true);
          }
        }
      }
    }

    ParticleSystem.update(dt);
  }
}