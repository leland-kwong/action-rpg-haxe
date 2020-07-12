package core;

import TestUtils.assert;

typedef AnimRef = {
  var frames: Array<Dynamic>;
  var duration: core.Types.Time;
  var startTime: core.Types.Time;
  var ?x: Float;
  var ?y: Float;
}

class Anim {
  public static function getFrame(
    anim: AnimRef, atTime: core.Types.Time
  ) {
    var timeElapsed = atTime - anim.startTime;
    var loopProgress = (timeElapsed % anim.duration) / anim.duration;
    var frameIndex = Math.floor(loopProgress * anim.frames.length);

    return anim.frames[frameIndex];
  }

  public static function test() {
    assert('[Anim/getFrame]', (passed) -> {
      var createTile = () -> h2d.Tile.fromColor(0xffffff);
      var anim: AnimRef = {
        frames: [createTile(), createTile()],
        duration: 1,
        startTime: 0
      };

      passed(
        getFrame(anim, 0.25) == anim.frames[0]
      );

      passed(
        getFrame(anim, 0.5) == anim.frames[1]
      );
    });
  }
}

class AnimEffect {
  static final animations: 
    Array<AnimRef> = [];
  static final oldAnimations:
    Map<Int, Bool> = new Map();

  public static function add(ref: AnimRef) {
    animations.push(ref);
  }

  public static function update(dt: Float) {
    // cleanup old animations
    {
      var numRemoved = 0;
      for (i => _ in oldAnimations) {
        animations.splice(i - numRemoved, 1);
        numRemoved += 1;
      }
      oldAnimations.clear();
    }
  }

  public static function render(
      time: Float) {

    for (i in 0...animations.length) {
      final ref = animations[i];
      final aliveTime = time - ref.startTime;
      final isDone = aliveTime > ref.duration 
        || oldAnimations.exists(i);

      if (isDone) {
        // TODO: cleanup using the same method
        // as the SpriteBatchSystem because
        // iterating over hash maps is way
        // slower than an array
        oldAnimations.set(i, false);
      } else {
        Main.Global.sb.emitSprite(
            ref.x,
            ref.y,
            core.Anim.getFrame(ref, time));
      }
    }
  }
}
