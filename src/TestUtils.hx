class TestUtils {
  public static function assert(
    defaultFailureMessage: String,
    testFn: (
      (passed: Bool, ?failureMessage: String) -> Void
    ) -> Void,
    ?afterTest: () -> Void = null,
    ?timeout = 5000
  ) {
    var doneState = false;

    function predicate(passed, ?failureMessage: String) {
      doneState = true;

      if (afterTest != null) {
        afterTest();
      }

      if (!passed) {
        final message = Utils.withDefault(
            failureMessage, 
            defaultFailureMessage);
        trace('[test fail] ${message}');
      }
    }

    try {
      testFn(predicate);
    } catch (err) {
      doneState = true;
      HaxeUtils.handleError(defaultFailureMessage)(err);
    }

    haxe.Timer.delay(() -> {
      if (!doneState) {
        trace(
            '[test timeout] ${defaultFailureMessage}');

        if (afterTest != null) {
          afterTest();
        }
      }
    }, timeout); 
  }
}
