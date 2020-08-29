class Experiment {
  public static function init() {
    final state = {
      isAlive: true
    };

    return () -> {
      state.isAlive = false;
    };
  }
}
