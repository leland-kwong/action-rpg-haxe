class Experiment {
  public static function init() {
    final state = {
      enabled: true
    };

    return () -> {
      state.enabled = false;
    };
  }
}
