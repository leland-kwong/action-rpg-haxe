class HaxeUtils {
  public static function handleError(
      message: String,
      ?onError: (error: Dynamic) -> Void) {

    return function haxeErrorHandler(error: Dynamic) {
      if (message != null) {
        trace(message, error);
      } else {
        trace(error);
      }

      final stack = haxe.CallStack.exceptionStack();
      trace(haxe.CallStack.toString(stack));

      if (onError != null) {
        onError(error);
      }
    }
  }

  public static function hasSameFields(
      value: Dynamic, 
      baseValue: Dynamic) {

    final t1 = Type.typeof(value);
    final t2 = Type.typeof(baseValue);

    // only allows checking of objects
    if (t1 != TObject || t2 != TObject) {
      return false;
    }

    final baseFields = Reflect.fields(baseValue);
    return Lambda.foreach(
        baseFields,
        (k) -> {
          Reflect.hasField(value, k);
        });
  }

  public static function tests() {
    TestUtils.assert(
        'should be same types',
        (passed) -> {
          final struct1 = {
            foo: 'foo'
          };

          final struct1_1 = {
            foo: 'bar'
          };
            
          passed(
              hasSameFields(struct1, struct1_1));
        });

    TestUtils.assert(
        'should be different fields',
        (passed) -> {
          final struct1 = {
            foo: 'foo'
          };

          final struct1_1 = {
            bar: 'foo'
          };

          passed(
              !hasSameFields(struct1, struct1_1));
        });
  }
}
