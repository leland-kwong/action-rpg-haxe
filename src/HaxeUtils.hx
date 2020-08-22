class HaxeUtils {
  public static function handleError(
      message: String,
      ?onError: (error: Dynamic) -> Void) {

    return function haxeErrorHandler(error: Dynamic) {
      final stack = haxe.CallStack.exceptionStack();

      if (message != null) {
        trace(message);
      }

      trace(error);
      trace(haxe.CallStack.toString(stack));

      if (onError != null) {
        onError(error);
      }
    }
  }
}
