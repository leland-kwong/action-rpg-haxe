package core;

import TestUtils.assert;

typedef AnimRef = {
  var frames: Array<Dynamic>;
  var duration: core.Types.Time;
  var startTime: core.Types.Time;
  // NOTE: optional properties on anonymous
  // structures are not performant. If this
  // becomes a problem, switching to classes
  // should probably speed things up
  var ?dx: Float;
  var ?dy: Float;
  var ?x: Float;
  var ?y: Float;
  var ?z: Float;
  var ?angle: Float;
  var ?effectCallback: SpriteBatchSystem.EffectCallback;
}

class Anim {
  public static function getFrame(
    anim: AnimRef, atTime: core.Types.Time
  ) {
    var timeElapsed = atTime - anim.startTime;
    var loopProgress = ((timeElapsed % anim.duration) / anim.duration) % 1;
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
        getFrame(anim, 0.25) == anim.frames[0]);

      passed(
        getFrame(anim, 0.5) == anim.frames[1]);

      passed(
         getFrame(anim, 1.5) == anim.frames[1]);
    });
  }
}

// creates long-lived animations
// and automatically cleans up old animations
class AnimEffect {
  public static var nextAnimations: 
    Array<AnimRef> = [];
  static var curAnimations: 
    Array<AnimRef> = [];

  public static function add(ref: AnimRef) {
    nextAnimations.push(ref);
  }

  public static function update(dt: Float) {
    curAnimations = nextAnimations;
    nextAnimations = [];
  }

  public static function render(time: Float) {
    for (ref in curAnimations) {
      final aliveTime = time - ref.startTime;
      final isAlive = aliveTime < ref.duration;
      final progress = aliveTime / ref.duration;
      final dx = ref.dx == null ? 0 : ref.dx;
      final dy = ref.dy == null ? 0 : ref.dy;

      if (isAlive) {
        Main.Global.sb.emitSprite(
            ref.x + dx * progress,
            ref.y + dy * progress,
            core.Anim.getFrame(ref, time),
            ref.angle,
            ref.effectCallback,
            ref.z);
        nextAnimations.push(ref);
      }
    }
  }
}
