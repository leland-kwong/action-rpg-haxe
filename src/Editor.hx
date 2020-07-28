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
    actions: new Array<Dynamic>(),
    activeLayerId: 'layer_a',
    tileRowsByLayerId: new Map<
      String,
      Map<Int, h2d.TileGroup>
    >()
  };

  // state to be serialized and saved
  static var editorState = {
    translate: {
      x: 0,
      y: 0
    },
    layerOrderById: [
      'layer_a',
      'layer_b'
    ],
    gridByLayerId: [
    'layer_a' =>  Grid.create(16),
    'layer_b' =>  Grid.create(16),
    ],
    itemTypeById: new Map<String, String>()
  };

  public static function sendAction(
      state: Dynamic, 
      action: Dynamic) {
    state.actions.push(action);
  }

  public static function init() {
    final spriteSheetTile = 
      hxd.Res.sprite_sheet_png.toTile();
    final spriteSheetData = Utils.loadJsonFile(
        hxd.Res.sprite_sheet_json).frames;
    final sbs = new SpriteBatchSystem(
        Main.Global.uiRoot);
    final activeGrid = editorState.gridByLayerId.get(
        localState.activeLayerId);
    final cellSize = activeGrid.cellSize;

    final insertSquare = (gridX, gridY, id, objectType) -> {
      final cx = (gridX * cellSize) + (cellSize / 2);
      final cy = (gridY * cellSize) + (cellSize / 2);

      Grid.setItemRect(
          activeGrid,
          cx, 
          cy,
          cellSize,
          cellSize,
          id);

      editorState.itemTypeById
        .set(id, objectType);

      sendAction(localState, {
        type: 'PAINT_CELL',
        x: cx,
        y: cy,
        gridX: gridX,
        gridY: gridY,
        spriteKey: objectMetaByType
          .get(objectType).spriteKey
      });
    };

    final removeSquare = (gridX, gridY, width, height) -> {
      final cx = (gridX * cellSize) + (cellSize / 2);
      final cy = (gridY * cellSize) + (cellSize / 2);
      final items = Grid.getItemsInRect(
          activeGrid,
          cx,
          cy,
          cellSize,
          cellSize);

      for (key in items) {
        Grid.removeItem(
            activeGrid,
            key);
        editorState.itemTypeById.remove(key);
      }

      sendAction(localState, {
        type: 'CLEAR_CELL',
        x: cx,
        y: cy,
        gridX: gridX,
        gridY: gridY,
      });
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
      Main.Global.logData.activeLayer = localState.activeLayerId;

      {
        final tileRowsRedrawn: Map<Int, Bool> = new Map();
        // [SIDE-EFFECT] creates a layer if it doesn't exist
        final activeTileRows = {
          final activeLayerId = localState.activeLayerId;
          final tileRows = localState.tileRowsByLayerId
            .get(activeLayerId);

          if (tileRows == null) {
            final newTileRows = new Map();
            localState.tileRowsByLayerId.set(
                activeLayerId,
                newTileRows);
            newTileRows;
          } else {
            tileRows;
          }
        }

        //TODO: sort tileroups by layer as well

        // sort tilegroups by layer order and 
        // row position so they draw properly
        {
          final rowIndices = [];
          for (rowIndex in activeTileRows.keys()) {
            rowIndices.push(rowIndex);
          }
          rowIndices.sort((a, b) -> {
            if (a < b) {
              return -1;
            }

            if (a > b) {
              return 1;
            }

            return 0;
          });
          for (rowIndex in rowIndices) {
            Main.Global.staticScene.addChild(
                activeTileRows.get(rowIndex));
          }
        }

        for (action in localState.actions) {
          switch (action.type) {
            case 
                'PAINT_CELL'
              | 'CLEAR_CELL': {

                final cellSize = activeGrid.cellSize;
                final rowIndex = action.gridY;
                  final tg = {
                    final tg = activeTileRows.get(rowIndex);

                    if (tg == null) {
                      final newTg = new h2d.TileGroup(
                          spriteSheetTile,
                          Main.Global.staticScene);
                      activeTileRows.set(rowIndex, newTg);
                      newTg;
                    } else {
                      tg;
                    }
                  };

                // clear row first
                if (tileRowsRedrawn.get(rowIndex) == null) {
                  tileRowsRedrawn.set(rowIndex, true);
                  tg.clear();
                
                  final gridRow = Utils.withDefault(
                      activeGrid.data.get(rowIndex),
                      new Map());
                  // repaint row
                  for (colIndex => cellData in gridRow) {
                    for (itemId in cellData) {
                      final objectType = editorState.itemTypeById
                        .get(itemId);
                      final spriteKey = objectMetaByType
                        .get(objectType).spriteKey;
                      final spriteData = Reflect.field(
                          spriteSheetData,
                          spriteKey);
                      final tile = spriteSheetTile.sub(
                          spriteData.frame.x,
                          spriteData.frame.y,
                          spriteData.frame.w,
                          spriteData.frame.h);
                      tile.setCenterRatio(
                          spriteData.pivot.x,
                          spriteData.pivot.y);
                      tg.add(
                          colIndex * cellSize + (cellSize / 2),
                          action.y,
                          tile);
                    }
                  }
                }
              }

            default: {}
          }
        }

        // clear old actions list
        localState.actions = [];
      }

      Main.Global.logData.editor = {
        panning: isPanning,
        editorMode: Std.string(editorMode),
        // editorState: editorState
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

        if (Key.isPressed(Key.NUMBER_1)) {
          localState.activeLayerId = 'layer_a';
        }

        if (Key.isPressed(Key.NUMBER_2)) {
          localState.activeLayerId = 'layer_b';
        }
      }

      if (previousButtonDown != buttonDown) {
        previousButtonDown = buttonDown;
        dragStartPos.x = Std.int(mx);
        dragStartPos.y = Std.int(my);
      }

      // handle grid interaction
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

      Main.Global.staticScene.scaleMode = ScaleMode.Zoom(
          zoom);
      Main.Global.staticScene.x = editorState.translate.x / zoom;
      Main.Global.staticScene.y = editorState.translate.y / zoom;

      return true;
    }

    function render(time) {
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
      final grid = activeGrid;
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
