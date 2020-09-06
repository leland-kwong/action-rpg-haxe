// an example on how to zoom relative to the mouse position

class ZoomPan {
  static function winMousePos() {
    final win = hxd.Window.getInstance();
    final wmx = win.mouseX;
    final wmy = win.mouseY;

    return {
      x: wmx,
      y: wmy
    };
  }

  public static function init() {
    final screenWidth = 1920;
    final screenHeight = 1080;
    final vec2 = (x, y) -> ({  
      x: x,
      y: y
    });
    final state = {
      zoom: 1.0,
      translate: {
        x: 100.0,
        y: 100.0
      },
      screenTranslate: {
        x: 0.0,
        y: 0.0
      },
      activeCircleId: 'c1',
      lockToCircle: true
    };
    final s2d = Main.Global.staticScene;
    final g = new h2d.Graphics(s2d);
    final circlesById = [
      'c1' => {
        x: 300.0,
        y: 100.0,
        radius: 25,
        color: 0xffffff
      },
      'c2' => {
        x: 500.0,
        y: 100.0,
        radius: 25,
        color: 0xe4e713
      }
    ];

    final updateCanvas = () -> {
      g.clear();
      
      // draw grid lines
      {
        final gridSize = 100;
        g.lineStyle(1, 0xffffff, 0.3);
        for (gridX in 0...Math.round((screenWidth / gridSize))) {
          g.drawRect(gridX * gridSize, 0, 1, screenHeight);
        }

        for (gridY in 0...Math.round((screenHeight / gridSize))) {
          g.drawRect(0, gridY * gridSize, screenWidth, 1);
        }
      }
      
      // draw circle objects
      {
        g.lineStyle(0, 0xffffff);
        for (_ => c in circlesById) {
          g.beginFill(c.color, 0.5);
          g.drawCircle(c.x, c.y, c.radius);
        }
      }

      // draw mouse relative to canvas
      {
        final wm = winMousePos();
        g.beginFill(0x2cb5e7, 0.8); 
        g.drawCircle(
            wm.x / state.zoom 
            - state.screenTranslate.x 
            - state.translate.x, 
            wm.y / state.zoom 
            - state.screenTranslate.y 
            - state.translate.y,
            15);
      }
    }


    final handleZoom = (e: hxd.Event) -> {
      if (e.kind == hxd.Event.EventKind.EWheel) {
        final wm = winMousePos();
        final dz = (e.wheelDelta / 10);
        final newZoom = Math.max(1.0, state.zoom - dz);
        final zoomDiff = newZoom - state.zoom;
        final translate = state.translate;
        final st = state.screenTranslate;
        final screenWidth = 1920;
        final screenHeight = 1080;
        final circle = circlesById.get(state.activeCircleId);
        final screenZoomTo = {
          x: screenWidth  / 4 * 2,
          y: screenHeight / 4 * 2
        };
        final zoomPos = {
          x: (state.lockToCircle ? wm.x : screenZoomTo.x) / newZoom,
          y: (state.lockToCircle ? wm.y : screenZoomTo.y) / newZoom 
        };
        final screenAdjust = {
          x: wm.x / newZoom 
            // readjust according to previous mouse zoom position
            - (wm.x / state.zoom - state.screenTranslate.x),
          y: wm.y / newZoom 
            - (wm.y / state.zoom - state.screenTranslate.y)
        };

        // trace(Lambda.map([
        //     wm.x / state.zoom - state.screenTranslate.x,
        //     wm.y / state.zoom - state.screenTranslate.y,
        //     state.screenTranslate.x,
        //     state.screenTranslate.y], Math.round));

        state.zoom = newZoom;
        state.screenTranslate.x = screenAdjust.x;
        state.screenTranslate.y = screenAdjust.y;

      }
    }
    s2d.addEventListener(handleZoom);

    Main.Global.hooks.update.push((dt) -> {
      updateCanvas();
      final winMouse = winMousePos();
      Main.Global.logData.mouseToCanvas = {
        x: Math.floor(winMouse.x / state.zoom),
        y: Math.floor(winMouse.y / state.zoom),
      };
      Main.Global.logData.winMouse = winMousePos();
      Main.Global.logData.zoomProgramState = state;
      s2d.scaleMode = ScaleMode.Zoom(state.zoom);
      s2d.x = state.screenTranslate.x + state.translate.x;
      s2d.y = state.screenTranslate.y + state.translate.y;

      final Key = hxd.Key;
      {
        final speed = 300;
        var dx = 0;
        var dy = 0;
        if (Key.isDown(Key.W)) {
          dy = -1;
        }
        if (Key.isDown(Key.S)) {
          dy = 1;
        }
        if (Key.isDown(Key.A)) {
          dx = -1;
        }
        if (Key.isDown(Key.D)) {
          dx = 1;
        }

        // pan the canvas
        state.translate.x += dx * dt * speed;
        state.translate.y += dy * dt * speed;
      }

      if (Key.isPressed(Key.NUMBER_1)) {
        state.activeCircleId = 'c1';
      }
      if (Key.isPressed(Key.NUMBER_2)) {
        state.activeCircleId = 'c2';
      }
      if (Key.isPressed(Key.TAB)) {
        state.lockToCircle = !state.lockToCircle;
      }

      return true;
    });
  }
}
