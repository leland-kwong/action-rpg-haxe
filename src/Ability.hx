import Entity;

class ChannelBeam {
  static final interval = 4;
  static final beamThickness = 15;
  public static final maxLength = 180;
  static final tickCooldown = 200 / 1000;
  static final baseSort = 10000000000000;
  static final state = {
    isAlive: true,
    possibleTargets: new Map<String, String>(),
    collidedTarget: 'NULL_ENTITY'
  };
    
  public static function getBeamBounds() {
    final s2d = Main.Global.rootScene;
    final player = Entity.getById('PLAYER');
    final minX = Math.min(player.x, s2d.mouseX);
    final maxX = Math.max(player.x, s2d.mouseX);
    final minY = Math.min(player.y, s2d.mouseY);
    final maxY = Math.max(player.y, s2d.mouseY);
    final width = maxX - minX;
    final height = maxY - minY;

    return {
      x: minX,
      y: minY,
      angle: Math.atan2(s2d.mouseY - player.y, s2d.mouseX - player.x),
      diagonalLength: Utils.distance(
          player.x, player.y, s2d.mouseX, s2d.mouseY),
      width: width,
      height: height
    };
  }

  public static function renderLaser(
    source: Entity,
    startPt, 
    endPt, 
    entityRef: Entity
  ) {
    final bounds = getBeamBounds();
    final hasCollision = entityRef != Entity.NULL_ENTITY;
    final desiredLength = Utils.distance(
        startPt.x, startPt.y, endPt.x, endPt.y);
    final dx = Math.cos(bounds.angle);
    final dy = Math.sin(bounds.angle);
    final length = Math.min(
        maxLength, 
        entityRef.id == 'NULL_ENTITY' 
        ? desiredLength
        : Utils.distance(
          startPt.x, startPt.y, 
          endPt.x, endPt.y));
    final laserHeadSpriteData = SpriteBatchSystem.getSpriteData(
        Main.Global.sb.batchManager.spriteSheetData,
        'ui/kamehameha_head'
        );
    final laserHeadWidth = laserHeadSpriteData.frame.w;
    final laserTailSpriteData = SpriteBatchSystem.getSpriteData(
        Main.Global.sb.batchManager.spriteSheetData,
        'ui/kamehameha_tail'
        );
    final laserTailWidth = laserTailSpriteData.frame.w 
      * laserTailSpriteData.pivot.x;
    final lhScaleY = Utils.rnd(1, 1.15);
    final lhSprite = Main.Global.sb.emitSprite(
        startPt.x,
        startPt.y,
        'ui/kamehameha_head',
        bounds.angle);
    lhSprite.scaleY = lhScaleY;
    // laser center
    final lcAngle = bounds.angle + (Math.PI / 2);
    final lcJitter = Utils.rnd(-0.5, 0.5);
    final lcx = startPt.x + dx * laserHeadWidth + Math.cos(lcAngle) * lcJitter;
    final lcy = startPt.y + dy * laserHeadWidth + Math.sin(lcAngle) * lcJitter;
    final centerSprite = Main.Global.sb.emitSprite(
        lcx,
        lcy,
        'ui/kamehameha_center_width_1',
        bounds.angle);
    final shaftLength = length - laserHeadWidth - laserTailWidth;
    centerSprite.scaleX = shaftLength;
    final tailSprite = Main.Global.sb.emitSprite(
        lcx + dx * (shaftLength + laserTailWidth),
        lcy + dy * (shaftLength + laserTailWidth),
        'ui/kamehameha_tail',
        bounds.angle);

    // deform tail sprite
    if (hasCollision) {
      final offsetX = -Utils.rnd(0, 1) * 2 * dx;
      final offsetY = -Utils.rnd(0, 1) * 2 * dy;
      centerSprite.scaleX += offsetX;
      tailSprite.x += offsetX;
      tailSprite.y += offsetY;
    }

    final isHitTick = Cooldown.has(entityRef.cds, 'hitFlash');
    if (hasCollision && isHitTick) {
      final duration = 0.2;
      final startTime = Main.Global.time;
      final numParticles = 5;

      final frames = ['ui/square_glow'];
      function particleEffectCallback(
          p: SpriteBatchSystem.SpriteRef) {
        final rawProgress = Easing.progress(
            startTime, Main.Global.time, duration);
        final progress = Easing.easeInBack(rawProgress);
        p.sortOrder += 5;
        p.scale = 3 * (1 - progress);
        p.g = 0.5 + 0.5 * (1 - progress);
        p.b = 1 - (progress * 1.5);
        p.a = 1 - progress;
      }

      for (_ in 0...numParticles) {
        final params = {
          frames: frames,
          duration: duration,
          startTime: startTime,
          x: tailSprite.x,
          y: tailSprite.y,
          dx: Utils.rnd(-1, 1, true) * 20,
          dy: Utils.rnd(-1, 1, true) * 20,
          angle: Utils.rnd(0, 2) * Math.PI,
          effectCallback: particleEffectCallback
        }

        core.Anim.AnimEffect.add(params);
      }
    }
  }

  public static function run(
      source: Entity,
      collisionFilter): EntityId {
    state.possibleTargets.clear();

    final bounds = getBeamBounds();
    final dx = Math.cos(bounds.angle);
    final dy = Math.sin(bounds.angle);
    final source = Entity.getById('PLAYER');
    final numChecks = maxLength / interval;
    Main.Global.logData.numLaserChecks = numChecks;
    for (i in 0...Std.int(numChecks)) {
      final x = source.x + dx * i * interval;
      final y = source.y + dy * i * interval;
      for (collisionGrid in [
          Main.Global.dynamicWorldGrid,
          Main.Global.grid.obstacle,
      ]) {
        final entities = Grid.getItemsInRect(
            collisionGrid,
            x, y, 
            beamThickness, beamThickness);
        for (id in entities) {
          if (!collisionFilter(id)) {
            continue;
          }

          state.possibleTargets.set(id, id);

          final possibleTargetRef = Entity.getById(id);
          final dist = Utils.distance(
              x, 
              y, 
              possibleTargetRef.x, 
              possibleTargetRef.y);
          final isCollision = dist <= 
            (beamThickness / 2) + possibleTargetRef.radius;
          if (isCollision) {
            state.collidedTarget = id;

            if (!Cooldown.has(possibleTargetRef.cds, 'channelBeamHit')) {
              Cooldown.set(
                  possibleTargetRef.cds, 'channelBeamHit', tickCooldown);
              EntityStats.addEvent(
                  possibleTargetRef.stats, {
                    type: 'DAMAGE_RECEIVED',
                    value: {
                      baseDamage: 1,
                      sourceStats: source.stats
                    }
                  });
            }
            return possibleTargetRef.id;
          }
        }
      }
    }

    return 'NULL_ENTITY';
  }
}
