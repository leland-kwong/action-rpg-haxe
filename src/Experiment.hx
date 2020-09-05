class Experiment {
  public static function init() {
    final state = {
      isAlive: true
    };

    final scale = 4;
    final G = Main.Global;
    final sb = new SpriteBatchSystem(
        G.staticScene,
        hxd.Res.sprite_sheet_png,
        hxd.Res.sprite_sheet_json);

    G.staticScene.scaleMode = ScaleMode.Zoom(scale);

    function particleEffect(p: SpriteBatchSystem.SpriteRef) {
      final duration = 1.5;
      final progress = (G.time - p.createdAt) / duration;
      final colorProgress = Easing.easeOutExpo(progress);
      final sizeProgress = progress;
      final s = p.state;

      p.x = p.state.x + -p.state.dx * progress * 40;
      p.y = p.state.y + -p.state.dy * progress * 40;
      p.r = (1 - colorProgress);
      p.g = (1 - colorProgress);
      p.b = (1 - colorProgress);
      p.scale = sizeProgress * p.state.size;
      p.done = progress >= 1;
    }

    G.renderHooks.push((time) -> {
      final x = 200;
      final y = 100;

      final p = sb.emitSprite(
          x, 
          y, 
          'ui/gravity_field_core');
      p.sortOrder = 0;
      p.r = 0;
      p.g = 0;
      p.b = 0;
      p.scaleX = 1 + 0.1 * Math.sin(G.time * 2);
      p.scaleY = 1 + 0.1 * Math.cos(G.time * 2);

      if (Main.Global.tickCount % 10 == 0) {
        for (_ in 0...1) {
          final angle = Utils.rnd(0, 5) * Math.PI;
          final dx = Math.cos(angle);
          final dy = Math.sin(angle);
          final _x = x + dx * 40;
          final _y = y + dy * 40;
          final s = sb.emitSprite(
              _x,
              _y,
              'ui/gravity_field_particle');
          s.sortOrder = 2;
          s.effectCallback = particleEffect;
          s.state = {
            size: Utils.rnd(1, 1.2),
            x: _x,
            y: _y,
            dx: dx,
            dy: dy,
          };
        }
      }

      return true;
    });

    return () -> {
      state.isAlive = false;
    };
  }
}
