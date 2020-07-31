
typedef StackRef = Array<{
  label: String,
  fn: () -> Void
}>;

class Stack {
  public static function push(sr: StackRef, label, fn) {
    sr.push({
      label: label, 
      fn: fn
    });
  }

  public static function pop(sr: StackRef) {
    final item = sr.pop();

    if (item != null) {
      item.fn();
    }
  }
}
