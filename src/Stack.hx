
typedef StackItem = {
  label: String,
  fn: () -> Void
};

typedef StackRef = Array<StackItem>;

class Stack {
  public static function exists(sr: StackRef, label) {
    return Lambda.exists(sr, (item) -> {
      return item.label == label;
    });
  }

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
