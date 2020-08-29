class Experiment {
  static function getBeamBounds() {
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

  public static function init() {
    final state = {
      isAlive: true,
      possibleTargets: new Map<String, String>(),
      collidedTarget: 'NULL_ENTITY'
    };
    final interval = 4;
    final beamThickness = 15;
    final maxLength = 180;

    Main.Global.renderHooks.push((time) -> {
      final baseSort = 10000000000000;
      final bounds = getBeamBounds();
      final source = Entity.getById('PLAYER');

      // draw laser
      function renderLaser(startPt, endPt) {
        final desiredLength = Utils.distance(
            startPt.x, startPt.y, endPt.x, endPt.y);
        final length = Math.min(
            maxLength, 
            state.collidedTarget == 'NULL_ENTITY' 
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
        final sprite = Main.Global.sb.emitSprite(
            source.x,
            source.y,
            'ui/kamehameha_head',
            bounds.angle);
        final lcx = source.x + Math.cos(bounds.angle) * laserHeadWidth;
        final lcy = source.y + Math.sin(bounds.angle) * laserHeadWidth;
        final sprite = Main.Global.sb.emitSprite(
            lcx,
            lcy,
            'ui/kamehameha_center_width_1',
            bounds.angle);
        final shaftLength = length - laserHeadWidth - laserTailWidth;
        sprite.batchElement.scaleX = shaftLength;
        final sprite = Main.Global.sb.emitSprite(
            lcx + Math.cos(bounds.angle) * (shaftLength + laserTailWidth),
            lcy + Math.sin(bounds.angle) * (shaftLength + laserTailWidth),
            'ui/kamehameha_tail',
            bounds.angle);
      }
      renderLaser(
          source,
          state.collidedTarget == 'NULL_ENTITY' 
          ? {
            x: Main.Global.rootScene.mouseX,
            y: Main.Global.rootScene.mouseY,
          } 
          : Entity.getById(state.collidedTarget));

      // show all locations queried
      function renderLocationsQueried() {
        final dx = Math.cos(bounds.angle);
        final dy = Math.sin(bounds.angle);
        for (i in 0...Std.int(bounds.diagonalLength / interval)) {
          final x = source.x + dx * i * interval;
          final y = source.y + dy * i * interval;
          final sprite = Main.Global.sb.emitSprite(
              x - beamThickness / 2,
              y - beamThickness / 2,
              'ui/square_white');
          sprite.sortOrder = baseSort + 1;
          sprite.batchElement.r = 0.;
          sprite.batchElement.b = 0.;
          sprite.batchElement.a = 0.5;
          sprite.batchElement.scaleX = beamThickness;
          sprite.batchElement.scaleY = beamThickness;
        }
      }
      // renderLocationsQueried();

      // show collisions
      function renderCollisions() {
        for (id in state.possibleTargets) {
          final ref = Entity.getById(id);
          final renderSize = ref.radius * 2;
          final sprite = Main.Global.sb.emitSprite(
              ref.x - renderSize / 2,
              ref.y - renderSize / 2,
              'ui/square_white');
          sprite.sortOrder = baseSort + 2;
          sprite.batchElement.a = 0.5;
          sprite.batchElement.scaleX = renderSize;
          sprite.batchElement.scaleY = renderSize;

          if (state.collidedTarget == id) {
            sprite.batchElement.r = 1.;
            sprite.batchElement.g = 0.;
            sprite.batchElement.b = 0.;
            return;
          }
        }
      }
      // renderCollisions();

      return state.isAlive;
    });

    function findCollisions() {
      final bounds = getBeamBounds();
      state.possibleTargets.clear();
      state.collidedTarget = 'NULL_ENTITY';
      final dx = Math.cos(bounds.angle);
      final dy = Math.sin(bounds.angle);
      final source = Entity.getById('PLAYER');
      final numChecks = Math.min(maxLength, bounds.diagonalLength) 
        / interval;
      final idsToIgnore = [
        'PLAYER' => true
      ];
      Main.Global.logData.numLaserChecks = numChecks;
      for (i in 0...Std.int(numChecks)) {
        final x = source.x + dx * i * interval;
        final y = source.y + dy * i * interval;
        for (collisionGrid in [
            Main.Global.dynamicWorldGrid,
            Main.Global.obstacleGrid,
        ]) {
          final entities = Grid.getItemsInRect(
              collisionGrid,
              x, y, 
              beamThickness, beamThickness);
          for (id in entities) {
            if (idsToIgnore.exists(id)) {
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
              return;
            }
          }
        }
      }
    }

    Main.Global.updateHooks.push((dt) -> {
      findCollisions();
      return state.isAlive;
    });

    return () -> {
      state.isAlive = false;
    };
  }
}
