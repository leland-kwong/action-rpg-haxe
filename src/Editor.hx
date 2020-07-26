/*
 * [ ] paint objects by placing them anywhere
 * [ ] option to snap to grid
 */

enum EditorMode {
  Panning;
  Paint;
  Erase;
}

class Editor {
  static var previousButtonDown = -1;
  static var editorMode = EditorMode.Paint;
  static var isPanning = false;
  static var dragStartPos = {
    x: 0,
    y: 0
  };
  static var translate = {
    x: 0,
    y: 0
  };
  static var zoom = 2;

  // state to be serialized and saved
  static var editorState = {
    translate: {
      x: 0,
      y: 0
    },
    grid: Grid.create(16)
  };

  public static function init() {
    final cellSize = editorState.grid.cellSize;

    final insertSquare = (gridX, gridY) -> {
      Grid.setItemRect(
          editorState.grid,
          (gridX * cellSize) + (cellSize / 2),
          (gridY * cellSize) + (cellSize / 2),
          cellSize,
          cellSize,
          Utils.uid());
    };

    final removeSquare = (gridX, gridY) -> {
      final items = Grid.getItemsInRect(
          editorState.grid,
          (gridX * cellSize) + (cellSize / 2),
          (gridY * cellSize) + (cellSize / 2),
          cellSize,
          cellSize);

      for (key in items) {
        Grid.removeItem(
            editorState.grid,
            key);
      }
    };

    insertSquare(0, 0);
    insertSquare(1, 1);

    final handleZoom = (e: hxd.Event) -> {
      if (e.kind == hxd.Event.EventKind.EWheel) {
        zoom -= Std.int(e.wheelDelta);
      }
    }
    Main.Global.uiRoot.addEventListener(handleZoom);

    function update(dt) {
      Main.Global.logData.editor = {
        previousButtonDown: previousButtonDown,
        editorMode: Std.string(editorMode),
        dragStartPos: dragStartPos,
        translate: translate,
      };

      final Key = hxd.Key;
      final buttonDown = Main.Global.worldMouse.buttonDown;
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;

      isPanning = false; 

      if (Key.isDown(Key.SPACE)) {
        isPanning = true; 
      }

      if (Key.isPressed(Key.E)) {
        editorMode = EditorMode.Erase;
      }

      if (Key.isPressed(Key.B)) {
        editorMode = EditorMode.Paint;
      }

      if (previousButtonDown != buttonDown) {
        previousButtonDown = buttonDown;
        dragStartPos.x = Std.int(mx);
        dragStartPos.y = Std.int(my);
      }

      if (buttonDown == 0) {
        if (isPanning) {
          final dx = mx - dragStartPos.x;
          final dy = my - dragStartPos.y;

          editorState.translate.x = Std.int(translate.x + dx);
          editorState.translate.y = Std.int(translate.y + dy);
        } else {
          final tx = editorState.translate.x;
          final ty = editorState.translate.y;
          final key = 'white_square';
          final gridX = Math.floor((mx - tx) / cellSize / zoom);
          final gridY = Math.floor((my - ty) / cellSize / zoom);

          switch (editorMode) {
            case EditorMode.Erase: {
              removeSquare(
                  gridX,
                  gridY);
            }
                                   // painting
            case EditorMode.Paint: {
              insertSquare(
                  gridX,
                  gridY);
            }

            default: {}
          }
        }
      } else {
        translate.x = editorState.translate.x;
        translate.y = editorState.translate.y;
      }


      return true;
    }

    function render(time) {
      final grid = editorState.grid;
      final spriteEffect = (p) -> {
        final b: h2d.SpriteBatch.BatchElement = p.batchElement;
        b.scale = zoom;
      };
      for (y => row in grid.data) {
        for (x => col in row) {
          Main.Global.uiSpriteBatch.emitSprite(
              ((x * cellSize) + (cellSize / 2)) * zoom + editorState.translate.x,
              ((y * cellSize) + (cellSize / 2)) * zoom + editorState.translate.y,
              // 'ui/square_tile_test',
              'enemy-2_animation/idle-0',
              null,
              spriteEffect);
        }
      }

      return true;
    }

    Main.Global.updateHooks.push(update);
    Main.Global.renderHooks.push(render);
  }
}
