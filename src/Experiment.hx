class Experiment {
  public static function triggerAbility(
      x1: Float,
      y1: Float,
      sortOffset: Float,
      angle) {

    final startTime = Main.Global.time;
    final numParticles = 10;

    for (i in 
        -Std.int(numParticles / 2)...Std.int(numParticles / 2)) {
      final spreadAngle = Math.PI / 6;
      final angle2 = angle + 
        i * spreadAngle / numParticles
        + (Utils.irnd(-4, 4) * Math.PI / 30);
      final speed = 10 + Utils.irnd(-10, 10);
      final rotation = Math.PI * (0.25 + Utils.rnd(0, .15));
      final duration = 0.4 + Utils.rnd(-0.3, 0.3);

      core.Anim.AnimEffect.add({
        x: x1,
        y: y1,
        startTime: startTime,
        frames: [
          'ui/square_glow', 
        ],
        duration: duration,
        effectCallback: (p) -> {
          final progress = (Main.Global.time - startTime) 
            / duration;
          final elem = p.batchElement;
          final dx = Math.cos(angle2);
          final dy = Math.sin(angle2);
          final v1 = Easing.easeOutQuint(progress);
          final v2 = Easing.easeInQuint(progress);
          final gravity = 9;

          p.sortOrder = y1 + sortOffset + 2;
          elem.alpha = 1 - Easing.easeInQuint(progress);
          elem.scale = 2 * (1 - Easing.easeInQuint(progress));
          elem.x += dx * -1 * speed * v1;
          elem.y += dy * -1 * speed * v1 + (gravity * v2);
          elem.rotation = rotation;

          elem.g = Math.max(0.4, 1 - v2 / 1.5);
          elem.b = 1 - v2 * 2;
        }
      });

    }

    // render torch
    final torchDuration = 0.2;
    core.Anim.AnimEffect.add({
      x: x1,
      y: y1,
      startTime: startTime,
      frames: [
        'ui/flame_torch', 
      ],
      duration: torchDuration,
      effectCallback: (p) -> {
        final progress = (Main.Global.time - startTime) 
          / torchDuration;
        final v1 = Easing.easeOutQuint(progress);
        final v2 = Easing.easeInQuint(progress);
        final elem = p.batchElement;

        p.sortOrder += sortOffset + 1;
        elem.rotation = angle;
        // elem.scaleY = 1 - v2;
        elem.scaleX = 1 - v2;
        elem.alpha = 1 - v2;
      }
    });

    // muzzle flash
    core.Anim.AnimEffect.add({
      x: x1,
      y: y1,
      startTime: startTime,
      frames: [
        'ui/circle_gradient', 
      ],
      duration: torchDuration,
      effectCallback: (p) -> {
        final progress = (Main.Global.time - startTime) 
          / torchDuration;
        final v1 = Easing.easeInQuint(progress);
        final elem = p.batchElement;

        p.sortOrder += sortOffset + 2;
        elem.rotation = angle;
        elem.scaleY = 1 - v1;
        elem.scaleX = 1 - v1;
        elem.alpha = 1 - v1;
      }
    });
  }

  public static function init() {
    final s2d = Main.Global.rootScene;
    final state = {
      isAttacking: false,
    };

    // render background
    function renderBackground(time: Float) {
      final ref = Main.Global.sb.emitSprite(
          -240,
          -135,
          'ui/square_white');
      final elem = ref.batchElement;
      ref.sortOrder = 0;
      elem.scaleX = 480;
      elem.scaleY = 270;
      elem.r = 0.3;
      elem.g = 0.3;
      elem.b = 0.3;

      return true;
    }
    Main.Global.renderHooks.push(renderBackground);

    function renderPlayer(time: Float) {
      final spriteKey = state.isAttacking
        ? 'player_animation/attack-0'
        : 'player_animation/idle-0';
      final ref = Main.Global.sb.emitSprite(
          0,
          0,
          spriteKey);

      ref.sortOrder = 1;

      return true;
    }
    Main.Global.renderHooks.push(renderPlayer);

    Main.Global.updateHooks.push((dt) -> {
      if (Main.Global.worldMouse.clicked) {
        final startTime = Main.Global.time;
        final actionTime = 0.15;

        Main.Global.updateHooks.push((dt) -> {
          final aliveTime = Main.Global.time - startTime;

          state.isAttacking = aliveTime < actionTime;

          return aliveTime < actionTime;
        });
        

        final angle = Math.atan2(
            s2d.mouseY - 0,
            s2d.mouseX - 0);
        triggerAbility(
            10, -8, 8, angle);
      }

      return true;
    });

    return () -> {};
  }
}
