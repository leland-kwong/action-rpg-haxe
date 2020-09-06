class Effects {
  public static function playerLevelUp(gameState) {
    final win = hxd.Window.getInstance();

    final renderBackground = false;
    if (renderBackground) {
      final g = new h2d.Graphics(Main.Global.uiRoot);
      g.beginFill(0x99999);
      g.drawRect(
          0, 0, win.width, win.height);
    }

    function padText(
        text = '', 
        leftCount = 0, 
        rightCount = 0) {
      var newText = text;

      for (i in 0...leftCount) {
        newText = ' ' + newText;
      }

      for (i in 0...rightCount) {
        newText = newText + ' ';
      }

      return newText;
    }

    final humanizedLevel = Config.calcCurrentLevel(
        gameState.experienceGained) + 1;
    final textBlocks = [
      'level'.toUpperCase(),
      ' ${humanizedLevel} ',
      'reached!'.toUpperCase()
    ];

    final totalWidth = Gui.calcTextWidth(
        Fonts.title(), textBlocks.join(''));
    final rootNode = new h2d.Object();
    Main.Global.uiRoot.addChildAt(rootNode, 0);
    final bmp = new h2d.Bitmap(
        SpriteBatchSystem.makeTile(
          Main.Global.uiSpriteBatch.batchManager.spriteSheet,
          Main.Global.uiSpriteBatch.batchManager.spriteSheetData,
          'ui/notification_gradient'),
        rootNode);
    final textRoot = new h2d.Object(rootNode);
    rootNode.visible = false;
    rootNode.x = win.width / 2;
    rootNode.y = 100;
    bmp.color = new h3d.Vector(0, 0, 0, 1);
    bmp.y = -20;
    bmp.scaleX = ((totalWidth + 300) / 200);
    bmp.scaleY = 4 * 40;

    final tf1 = new h2d.Text(
        Fonts.title(),
        textRoot); 
    tf1.text = textBlocks[0];
    tf1.textAlign = Left;
    tf1.textColor = 0xfeae34;

    final tf2 = new h2d.Text(
        Fonts.title(),
        textRoot); 
    tf2.text = textBlocks[1];
    tf2.textAlign = Left;
    tf2.textColor = 0xffffff;

    final tf3 = new h2d.Text(
        Fonts.title(),
        textRoot); 
    tf3.text = textBlocks[2];
    tf3.textAlign = Left;
    tf3.textColor = 0xfeae34;

    tf1.x = -totalWidth / 2;
    tf2.x = -totalWidth / 2 + tf1.textWidth;
    tf3.x = -totalWidth / 2 + tf1.textWidth + tf2.textWidth;

    final tfHint = new h2d.Text(
        Fonts.primary(),
        textRoot); 
    final newLevel = 10;
    tfHint.text = 'You have gained a new level';
    tfHint.textColor = 0xf77622;
    tfHint.textAlign = Center;
    tfHint.y = tf1.y + tf1.textHeight + 20;

    var previousShine: h2d.Graphics = null;

    function runAnimation() {
      if (previousShine != null) {
        previousShine.remove();
      }

      function triggerAnimateOut(onComplete) {
        final duration = 0.25;
        final startedAt = Main.Global.time;

        Main.Global.hooks.update.push((dt) -> {
          final progress = (Main.Global.time - startedAt) / duration;

          rootNode.visible = true;
          rootNode.setScale(1 - Easing.easeInBack(progress));

          if (progress >= 1) {
            onComplete();
            return false;
          }

          return true;
        });
      }

      function triggerShine(onComplete) {
        final shine = new h2d.Graphics(Main.Global.uiRoot);
        final mask = new h2d.filter.Mask(textRoot, true, true);
        previousShine = shine;
        shine.lineStyle(50, 0xffffff);
        shine.lineTo(0, -100);
        shine.lineTo(100, 300);
        shine.alpha = 0;
        shine.filter = mask;

        final duration = 0.8;
        final startedAt = Main.Global.time;
        Main.Global.hooks.update.push((dt) -> {

          final progress = (Main.Global.time - startedAt) / duration;
          final bmpBounds = bmp.getBounds();
          shine.alpha = 1.;
          shine.y = bmpBounds.y - 10;
          shine.x = bmpBounds.x + progress * bmpBounds.width;

          if (progress >= 1) {
            shine.remove();
            onComplete();
          }

          return progress < 1;
        });
      }

      function triggerAnimateIn(onComplete) {
        final duration = 0.3;
        final startedAt = Main.Global.time;

        Main.Global.hooks.update.push((dt) -> {
          final progress = (Main.Global.time - startedAt) / duration;

          rootNode.visible = true;
          rootNode.rotation = (1 - Easing.easeOutBack(progress)) * -Math.PI / 20;
          rootNode.setScale(Easing.easeOutBack(progress));

          if (progress >= 1) {
            onComplete();
            return false;
          }

          return true;
        });
      }

      function triggerLightBeamOnPlayer() {
        final duration = 2.;
        final lengthAnimDuration = 0.5;
        final startedAt = Main.Global.time;

        Main.Global.hooks.render.push((time) -> {
          final p = Easing.progress(
              startedAt, Main.Global.time, duration);
          final p2 = Easing.progress(
              startedAt, Main.Global.time, lengthAnimDuration);
          final v = Easing.easeInExpo(p);
          final playerRef = Entity.getById('PLAYER');
          final scaleX = 20 * (1 - v);
          final xOffset = scaleX / 2;
          final length = Main.Global.mainCamera.h / 2;
          final beamRef = Main.Global.sb.emitSprite(
              playerRef.x - xOffset,
              playerRef.y - length,
              'ui/square_white');

          beamRef.sortOrder = playerRef.y - 1;
          beamRef.scaleX = scaleX;
          beamRef.scaleY = length * Easing.easeOutExpo(p2);
          beamRef.alpha = 0.9 - v;

          return p < 1; 
        });
      }
 
      triggerLightBeamOnPlayer();
      triggerAnimateIn(() -> {
        triggerShine(() -> {
          haxe.Timer.delay(() -> {
            triggerAnimateOut(() -> {
              rootNode.remove();
            });
          }, 2000);
        });
      }); 
    }

    runAnimation();
  }
}
