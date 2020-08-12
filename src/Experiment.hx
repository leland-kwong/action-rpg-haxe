class Experiment {
  public static function init() {
    final s2d = Main.Global.rootScene;
    final state = {
      playerPos: {
        x: 0.,
        y: 0.,
        facingX: 1,
      },
      isAttacking: false
    };

    function setColor(
        ref: SpriteBatchSystem.SpriteRef,
        r = 1., g = 1., b = 1., a = 1.) {

      final elem = ref.batchElement;

      elem.r = r;
      elem.g = g;
      elem.b = b;
      elem.a = a;
    }

    // render background
    Main.Global.renderHooks.push((time) -> {
      final ref = Main.Global.sb.emitSprite(
          -240,
          -135,
          'ui/square_white');
      final elem = ref.batchElement;
      elem.scaleX = 480;
      elem.scaleY = 270;
      elem.r = 0.5;
      elem.g = 0.5;
      elem.b = 0.5;

      final playerSpriteRef = Main.Global.sb.emitSprite(
          state.playerPos.x,
          state.playerPos.y,
          state.isAttacking 
          ? 'player_animation/attack-0'
          : 'player_animation/idle-0');
      playerSpriteRef.batchElement.scaleX = 
        state.playerPos.facingX;

      return true;
    });

    Main.Global.updateHooks.push((dt) -> {
      if (Main.Global.worldMouse.clicked) {
        final oldPos = Reflect.copy(state.playerPos);
        final startTime = Main.Global.time;
        final endX = s2d.mouseX;
        final endY = s2d.mouseY;

        function renderOldPosition(time: Float) {
          final duration = 0.3; 
          final aliveTime = time - startTime;
          final progress = aliveTime / duration;
          final ref = Main.Global.sb.emitSprite(
              oldPos.x,
              oldPos.y,
              'player_animation/idle-0');
          final elem = ref.batchElement;

          elem.r = 0;
          elem.g = 0;
          elem.b = 0;
          elem.alpha = 0.5 - Easing.easeInCirc(progress);
          elem.scaleX = state.playerPos.facingX;

          return progress < 1; 
        }
        Main.Global.renderHooks.push(
            renderOldPosition);

        final startedAt = Main.Global.time;
        final x = endX;
        final y = endY;
        final angle = Math.atan2(
            y - state.playerPos.y,
            x - state.playerPos.x);
        final dx = Math.cos(angle);
        final dy = Math.sin(angle);
        final dist = Utils.distance(
            state.playerPos.x,
            state.playerPos.y,
            endX,
            endY);
        final randOffset = Utils.irnd(0, 10);
        var isFirstFrame = true;
        final animLungeDist = 20;

        // render trail
        {
          final startTime = Main.Global.time;
          final duration = 0.2;

          core.Anim.AnimEffect.add({
            x: oldPos.x + dist * 0.2 * dx,
            y: oldPos.y + dist * 0.2 * dy,
            startTime: startTime,
            duration: duration,
            frames: [
              'player_animation/idle-0'
            ],
            effectCallback: (p) -> {
              final progress = (Main.Global.time - startTime) / duration;
              p.batchElement.alpha = 0.5 * (1 - progress);
              p.batchElement.scaleX = state.playerPos.facingX;
            }
          });
        }

        {
          final startTime = Main.Global.time;
          final duration = 0.2;

          core.Anim.AnimEffect.add({
            x: oldPos.x + dist * 0.4 * dx,
            y: oldPos.y + dist * 0.4 * dy,
            startTime: startTime,
            duration: duration,
            frames: [
              'player_animation/idle-0'
            ],
            effectCallback: (p) -> {
              final progress = (Main.Global.time - startTime) / duration;
              p.batchElement.alpha = 0.3 * (1 - progress);
              p.batchElement.scaleX = state.playerPos.facingX;
            }
          });
        }

        {
          final startTime = Main.Global.time;
          final duration = 0.2;

          core.Anim.AnimEffect.add({
            x: oldPos.x + dist * 0.7 * dx,
            y: oldPos.y + dist * 0.7 * dy,
            startTime: startTime,
            duration: duration,
            frames: [
              'player_animation/idle-0'
            ],
            effectCallback: (p) -> {
              final progress = (Main.Global.time - startTime) / duration;
              p.batchElement.alpha = 0.1 * (1 - progress);
              p.batchElement.scaleX = state.playerPos.facingX;
            }
          });
        }

        final lungeStartAt = 0.1;
        final lungeDuration = 0.2;
        final duration = lungeStartAt + lungeDuration;

        // handle lunge animation
        Main.Global.updateHooks.push((dt) -> {
          final aliveTime = Main.Global.time - startedAt;
          final progress = aliveTime / duration;
          final facingX = dx > 0 ? 1 : -1;

          if (aliveTime < lungeStartAt) {
            state.playerPos = {
              x: endX - animLungeDist * dx,
              y: endY - animLungeDist * dy,
              facingX: facingX
            };
          } else {
            final remainingTime = duration - aliveTime;
            final progress = (lungeDuration - remainingTime) 
              / lungeDuration; 
            final p = Easing.easeOutExpo(
                progress);
            state.playerPos = {
              x: endX - animLungeDist * dx * (1 - p),
              y: endY - animLungeDist * dy * (1 - p),
              facingX: facingX
            };
          }

          return progress < 1;
        });

        Main.Global.renderHooks.push((time) -> {
          final xOffset = 10;
          final yOffset = -8;
          final aliveTime = Main.Global.time - startedAt;
          final progress = (aliveTime) 
            / duration;

          if (aliveTime < lungeStartAt) {
            return true;
          }

          final posV = Easing.easeInCirc(progress);
          final facingX = dx > 0 ? 1 : -1;
          final spriteRef = Main.Global.sb.emitSprite(
              x + xOffset * facingX + dx * randOffset * posV, 
              y + yOffset + dy * randOffset * posV,
              'ui/melee_burst');
          spriteRef.sortOrder = y + 10;

          if (progress < 0.2) {
            final ref = Main.Global.sb.emitSprite(
              x + xOffset * facingX + dx * randOffset * posV * 0.1, 
              y + yOffset + dy * randOffset * posV * 0.1,
              'ui/melee_burst');

            ref.sortOrder = spriteRef.sortOrder + 1;
            setColor(ref, 0, 0, 0);
          } else {
            final b = spriteRef.batchElement;
            b.scale = 1 + Easing.easeInCirc(progress) * 0.3;
            b.alpha = 1 - Easing.easeInSine(progress);
          }

          final isAlive = progress < 1;

          state.isAttacking = isAlive;

          return isAlive;
        });
      }

      return true;
    });

    return () -> {};
  }
}
