class Test {
  public static function assert(
    failureMessage: String,
    testPredicate
  ) {
    if (!testPredicate()) {
      throw '[test fail] ${failureMessage}';
    }
  }
}