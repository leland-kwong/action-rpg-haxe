typedef CameraRef = {
  var x: Float;
  var y: Float;
  var w: Int;
  var h: Int;
  var following: Dynamic;
}

class Camera {
  public static function create(): CameraRef {
    return {
      x: 0.0,
      y: 0.0,
      w: 0,
      h: 0,
      following: null
    }
  }

  public static function setSize(ref: CameraRef, w, h) {
    ref.w = w;
    ref.h = h;
  }

  public static function follow(ref: CameraRef, object: Dynamic) {
    ref.following = object;
  }

  public static function toScreenPos(
      ref: CameraRef, worldPosX: Float, worldPosY: Float) {
    return [
      worldPosX - ref.x + ref.w / 2,
      worldPosY - ref.y + ref.h / 2,
    ];
  }

  public static function update(ref: CameraRef, dt: Float) {
    var f = ref.following;

    if (f == null) {
      return;
    }

    ref.x = f.x;
    ref.y = f.y;
  }
}
