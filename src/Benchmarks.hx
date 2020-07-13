class Benchmarks {
  public static function benchSprites() {
    final onUpdate = (_) -> {
      final effectCallback = (p) -> {
        final scale = 1;

        p.sortOrder = 1.0;
        p.batchElement.scaleX = scale * 1.0;
        p.batchElement.scaleY = scale * 1.0;
      }

      for (_ in 0...2800) {
        Main.Global.uiSpriteBatch.emitSprite(
            0,
            0,
            'ui/square_white',
            null,
            effectCallback);
      }
    };

    Main.Global.updateHooks.push(onUpdate);
  }
}
