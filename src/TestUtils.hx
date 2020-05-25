class TestUtils {
  public static function assert(
    failureMessage: String,
    testFn: (
      (passed: Bool) -> Void
    ) -> Void,
    afterTest: () -> Void = null
  ) {
    function predicate(passed) {
      if (!passed) {
        throw '[test fail] ${failureMessage}';
      }

      if (afterTest != null) {
        afterTest();
      }
    }
    testFn(predicate);
  }
}
