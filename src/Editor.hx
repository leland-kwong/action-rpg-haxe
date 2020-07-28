/*
 * [x] paint objects by placing them anywhere
 * [ ] layer system
 * [ ] option to toggle snap to grid
 */

enum EditorMode {
  Panning;
  Paint;
  Erase;
}

class Editor {
  static final objectMetaByType = [
    'pillar' => {
      spriteKey: 'ui/pillar',
    },
    'enemy_1' => {
      spriteKey: 'enemy-2_animation/idle-0',
    },
    'white_square' => {
      spriteKey: 'ui/square_tile_test',
    },
  ];

  static var previousButtonDown = -1;
  static var editorMode = EditorMode.Paint;
  static var isPanning = false;
  static var showObjectCenters = false;
  static var dragStartPos = {
    x: 0,
    y: 0
  };
  static var translate = {
    x: 0,
    y: 0
  };
  static var zoom = 2.0;
  static var selectedObjectType = 'white_square';
  static var objectTypeMenu: Array<{
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    type: String
  }> = [];

  static var localState = {
    tileRows: new Map<Int, h2d.TileGroup>()
  };

  // state to be serialized and saved
  static var editorState = {
    translate: {
      x: 0,
      y: 0
    },
    grid: Grid.create(16),
    itemTypeById: new Map<String, String>()
  };

  static function tileGroupTest(
      spriteSheetTile, 
      spriteSheetData,
      rowIndex) {
    final tg = {
      final tg = localState.tileRows.get(rowIndex);

      if (tg == null) {
        final newTg = new h2d.TileGroup(
              spriteSheetTile,
              Main.Global.staticScene);
        localState.tileRows.set(rowIndex, 
           newTg);
        newTg;
      } else {
        tg;
      }
    }
    final pillarTile = {
      final spriteData = Reflect.field(
          spriteSheetData,
          'ui/pillar');
      spriteSheetTile.sub(
          spriteData.frame.x,
          spriteData.frame.y,
          spriteData.frame.w,
          spriteData.frame.h);
    }
    final squareTile = {
      final spriteData = Reflect.field(
          spriteSheetData,
          'ui/square_tile_test');
      spriteSheetTile.sub(
          spriteData.frame.x,
          spriteData.frame.y,
          spriteData.frame.w,
          spriteData.frame.h);
    }

    final refreshTileGroup = (dt) -> {
      tg.clear();

      for (x in 100...1000) {
        tg.add(x * 40, rowIndex * 40, pillarTile);
      }

      return true;
    };

    if (rowIndex == 0) {
      Main.Global.updateHooks.push(refreshTileGroup);
    }
    refreshTileGroup(0);
  }

  public static function init() {
    final sbs = new SpriteBatchSystem(
        Main.Global.staticScene);

    final testTileGroup = false;

    if (testTileGroup) {
      final spriteSheetTile = 
        hxd.Res.sprite_sheet_png.toTile();
      final spriteSheetData = Utils.loadJsonFile(
          hxd.Res.sprite_sheet_json).frames;
      var rowIndex = 0;
      Main.Global.updateHooks.push((dt) -> {
        for (_ in 0...6) {
          tileGroupTest(
              spriteSheetTile, 
              spriteSheetData,
              rowIndex);
          rowIndex += 1;
        }

        return rowIndex < 800;
      });
    }

    final cellSize = editorState.grid.cellSize;

    final insertSquare = (gridX, gridY, id, objectType) -> {
      Grid.setItemRect(
          editorState.grid,
          (gridX * cellSize) + (cellSize / 2),
          (gridY * cellSize) + (cellSize / 2),
          cellSize,
          cellSize,
          id);

      editorState.itemTypeById
        .set(id, objectType);
    };

    final removeSquare = (gridX, gridY, width, height) -> {
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
        editorState.itemTypeById.remove(key);
      }
    };

    final handleZoom = (e: hxd.Event) -> {
      if (e.kind == hxd.Event.EventKind.EWheel) {
        zoom = Math.max(1, zoom - Std.int(e.wheelDelta));
      }
    }
    Main.Global.staticScene.addEventListener(handleZoom);

    function toGridPos(screenX: Float, screenY: Float) {
      final tx = editorState.translate.x;
      final ty = editorState.translate.y;
      final gridX = Math.floor((screenX - tx) / cellSize / zoom);
      final gridY = Math.floor((screenY - ty) / cellSize / zoom);

      return [gridX, gridY];
    }

    function updateObjectTypeList() {
      final win = hxd.Window.getInstance();
      var oy = 50;
      final itemSize = 50; 
      final x = win.width - 200;
      final scale = 2;

      objectTypeMenu = [];

      for (type => meta in objectMetaByType) {
        objectTypeMenu.push({
          x: x,
          y: oy,
          width: itemSize,
          height: itemSize,
          type: type,
        });

        oy += itemSize * scale;
      }
    }

    function update(dt) {
      Main.Global.logData.editor = {
        panning: isPanning,
        editorMode: Std.string(editorMode),
        editorState: editorState
      };

      final Key = hxd.Key;
      final buttonDown = Main.Global.worldMouse.buttonDown;
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;

      isPanning = false; 
      showObjectCenters = false;
      updateObjectTypeList();

      final menuItemHovered  = Lambda.fold(
          objectTypeMenu,
          (menuItem, result: { value: String, itemDist: Float }) -> {
            final d = Utils.distance(mx , my, menuItem.x, menuItem.y);

            if (d < result.itemDist) {
              return {
                value: menuItem.type,
                itemDist: d
              };
            }

            return result;
          }, {
            value: null,
            itemDist: 50
          });
      final isMenuItemHovered = menuItemHovered.value != null;
      // handle object menu selection
      if (isMenuItemHovered && 
          Main.Global.worldMouse.clicked) {
        selectedObjectType = menuItemHovered.value;
      }

      // handle hotkeys 
      {
        if (Key.isDown(Key.SPACE)) {
          isPanning = true; 
        }

        if (Key.isDown(Key.C)) {
          showObjectCenters = true;
        }

        if (Key.isPressed(Key.E)) {
          editorMode = EditorMode.Erase;
        }

        if (Key.isPressed(Key.B)) {
          editorMode = EditorMode.Paint;
        }
      }

      if (previousButtonDown != buttonDown) {
        previousButtonDown = buttonDown;
        dragStartPos.x = Std.int(mx);
        dragStartPos.y = Std.int(my);
      }

      if (buttonDown == 0 && !isMenuItemHovered) {
        if (isPanning) {
          final dx = mx - dragStartPos.x;
          final dy = my - dragStartPos.y;

          editorState.translate.x = Std.int(translate.x + dx);
          editorState.translate.y = Std.int(translate.y + dy);
        } else {
          final mouseGridPos = toGridPos(mx, my);
          final gridX = mouseGridPos[0];
          final gridY = mouseGridPos[1];

          switch (editorMode) {
            case EditorMode.Erase: {
              removeSquare(
                  gridX,
                  gridY,
                  cellSize,
                  cellSize);
            }

            // replaces the cell with new value
            case EditorMode.Paint: {
              removeSquare(
                  gridX,
                  gridY,
                  cellSize,
                  cellSize);

              insertSquare(
                  gridX,
                  gridY,
                  Utils.uid(),
                  selectedObjectType);
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
      final mx = Main.Global.staticScene.mouseX;
      final my = Main.Global.staticScene.mouseY;
      final grid = editorState.grid;
      final spriteEffectZoom = (p) -> {
        final b: h2d.SpriteBatch.BatchElement = p.batchElement;
        b.scale = zoom;
      };
      final centerCircleRadius = 10;
      final centerCircleSpriteEffect = (p) -> {
        final b: h2d.SpriteBatch.BatchElement = p.batchElement;
        p.sortOrder = 99999999.0;
        // b.g = 0.8;
        b.b = 0.2;
        b.scale = centerCircleRadius * 2;
      };

      // render items in grid
      for (itemId => bounds in grid.itemCache) {
        final width = bounds[1] - bounds[0];
        final cx = bounds[0] + width / 2;
        final height = bounds[3] - bounds[2];
        final cy = bounds[2] + height / 2;
        final itemType = editorState.itemTypeById.get(itemId);
        final objectMeta = objectMetaByType.get(itemType);
        final screenCX = ((cx * cellSize)) * zoom + editorState.translate.x;
        final screenCY = ((cy * cellSize)) * zoom + editorState.translate.y;

        sbs.emitSprite(
            screenCX,
            screenCY,
            // 'ui/square_tile_test',
            objectMeta.spriteKey,
            null,
            spriteEffectZoom);

        if (showObjectCenters) {
          sbs.emitSprite(
              screenCX - centerCircleRadius,
              screenCY - centerCircleRadius,
              'ui/square_white',
              centerCircleSpriteEffect);
        }
      }

      // render object type menu options
      {
        final win = hxd.Window.getInstance();
        var y = 50;
        final x = win.width - 200;
        final scale = 2;
        final spriteEffect = (p) -> {
          final b: h2d.SpriteBatch.BatchElement = p.batchElement;
          b.scale = scale;
        };
        for (menuItem in objectTypeMenu) {
          final spriteKey = objectMetaByType
            .get(menuItem.type)
            .spriteKey;
          sbs.emitSprite(
              menuItem.x,
              menuItem.y,
              spriteKey,
              null,
              spriteEffect);

          y += menuItem.height * scale;
        }
      }

      final drawSortSelection = 1000 * 1000;
      // show selection at cursor
      if (editorMode == EditorMode.Paint) {
        final spriteKey = objectMetaByType
          .get(selectedObjectType).spriteKey;
        sbs.emitSprite(
            mx,
            my,
            spriteKey,
            null,
            (p) -> {
              final b: h2d.SpriteBatch.BatchElement = 
                p.batchElement;
              b.alpha = 0.3;
              p.sortOrder = drawSortSelection;
              spriteEffectZoom(p);
            });
      }

      // show hovered cell at cursor
      {
        final mouseGridPos = toGridPos(
            mx, 
            my);
        final hc = cellSize / 2;
        sbs.emitSprite(
            (((mouseGridPos[0] * cellSize) + hc) * zoom) + 
            editorState.translate.x,
            (((mouseGridPos[1] * cellSize) + hc) * zoom) + 
            editorState.translate.y,
            'ui/square_tile_test',
            null,
            (p) -> {
              final b: h2d.SpriteBatch.BatchElement = 
                p.batchElement;
              p.sortOrder = drawSortSelection - 1;
              b.b = 0;
              b.alpha = 0.3;
              spriteEffectZoom(p);
            });
      }

      return true;
    }

    Main.Global.updateHooks.push(update);
    Main.Global.renderHooks.push(render);
  }
}
