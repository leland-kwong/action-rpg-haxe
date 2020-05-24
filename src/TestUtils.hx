class TestUtils {
  public static function assert(
    failureMessage: String,
    testPredicate: () -> Bool,
    afterTest: () -> Void = null
  ) {
    if (!testPredicate()) {
      throw '[test fail] ${failureMessage}';
    }

    if (afterTest != null) {
      afterTest();
    }
  }
}
