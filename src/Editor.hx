/*
 * NOTE: To keep things simple, we will only store one id
 * per object in the grid since we can derive all the
 * object information directly from that id. This way we're
 * not having to deal with varying issues around objects
 * changing their size because their position remains static
 *
 * [x] paint objects by placing them anywhere
 * [x] basic layer system
 * [x] load state from disk
 * [ ] improve zoom ux
 * [ ] undo/redo system
 * [ ] option to toggle layer visibility
 * [ ] [BUG] Serializing state of large files can sometimes crash.
       One possible cause is that we're mutating state while the 
       thread is in mid-serialization. We need a better way of mutating
       state that doesn't interfere with the thread trying to access that 
       at the same time.
 * [ ] adjustable brush size to paint multiple items at once
 */

enum EditorMode {
  Panning;
  Paint;
  Erase;
}

typedef ProfilerRef = Map<String, {startedAt: Float, time: Float}>;
typedef EditorStateAction = {
  type: String,
  ?layerId: String,
  ?gridY: Int,
  ?translate: {
    x: Int,
    y: Int
  }  
};


class Profiler {
  public static function create(): ProfilerRef {
    final timesByLabel = new Map();

    return timesByLabel;
  }

  static function getTimeInstance(ref: ProfilerRef, label) {
    final inst = ref.get(label);

    if (inst == null) {
      final newInst = {startedAt: 0.0, time: 0.0};
      ref.set(label, newInst);

      return newInst;
    }

    return inst;
  }

  public static function start(ref: ProfilerRef, label) {
    getTimeInstance(ref, label).startedAt = Sys.cpuTime();
  }

  public static function end(ref: ProfilerRef, label) {
    final inst = getTimeInstance(ref, label);
    final executionTime = (Sys.cpuTime() - inst.startedAt) * 1000;
    inst.time = executionTime;

    return executionTime;
  }
}

class Editor {
  // all configuration stuff lives here
  static final config = {
    activeFile: 'editor-data/test_data.eds',
    objectMetaByType: [
      'pillar' => {
        spriteKey: 'ui/pillar',
      },
      'enemy_1' => {
        spriteKey: 'enemy-2_animation/idle-0',
      },
      'white_square' => {
        spriteKey: 'ui/square_tile_test',
      },
    ]
  }

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
  static var selectedObjectType = 'white_square';
  static var objectTypeMenu: Array<{
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    type: String
  }> = [];

  static var localState = {
    zoom: 2.0,
    previousButtonDown: -1,
    actions: new Array<EditorStateAction>(),
    stateToSave: null,
    // eds is short for `editor data state`
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
    updatedAt: Date.now(),
    layerOrderById: [
      'layer_a',
      'layer_b'
    ],
    gridByLayerId: [
    'layer_a' => Grid.create(16),
    'layer_b' => Grid.create(16),
    ],
    itemTypeById: new Map<String, String>()
  };

  public static function sendAction(
      state: Dynamic,
      action: Dynamic) {
    state.actions.push(action);
  }

  public static function init() {
    final profiler = Profiler.create();
    final spriteSheetTile =
      hxd.Res.sprite_sheet_png.toTile();
    final spriteSheetData = Utils.loadJsonFile(
        hxd.Res.sprite_sheet_json).frames;
    final sbs = new SpriteBatchSystem(
        Main.Global.uiRoot);
    final loadPath = config.activeFile;

    SaveState.load(
        loadPath,
        false,
        (unserialized) -> {
          if (unserialized == null) {
            trace('[editor load] no data to load at `${loadPath}`');

            return;
          }
          editorState = unserialized;

          var itemCount = 0;
          for (layerId => grid in editorState.gridByLayerId) {
            final gridData = grid.data;

            for (rowIndex => rowData in gridData) {

              itemCount += Lambda.count(rowData);

              sendAction(localState, {
                type: 'PAINT_CELL_FROM_LOADING_STATE',
                layerId: layerId,
                gridY: rowIndex,
              });
            }
          }

          Main.Global.logData.loadStateItemCount = itemCount;
        }, (err) -> {
          trace(
              '[editor error] failed to load `${loadPath}`', 
              err);
        });

    final autoSaveOnChange = () -> {
      final interval = 1 / 10;
      var savePending = false;

      while (true) {

        try {
          Sys.sleep(interval);

          final stateToSave = localState.stateToSave;
          final filePath = config.activeFile;
          if (!savePending && stateToSave != null) {
            // prevent another save from happening 
            // until this is complete
            savePending = true;
            localState.stateToSave = null;
            Profiler.start(profiler, 'serializeJson');
            final serialized = {
              haxe.Serializer.run(
                  stateToSave);
            }

            SaveState.save(
                serialized,
                filePath,
                null,
                (res) -> {
                  Profiler.end(profiler, 'serializeJson');
                  Main.Global.logData.editorPerf = profiler;
                  savePending = false;
                }, (error) -> {
                  trace(error);
                });
          }
        } catch (err) {
          trace(err);
        }
      }
    };

    sys.thread.Thread.create(autoSaveOnChange);

    final insertSquare = (gridRef, gridX, gridY, id, objectType) -> {
      final cellSize = gridRef.cellSize;
      final cx = (gridX * cellSize) + (cellSize / 2);
      final cy = (gridY * cellSize) + (cellSize / 2);

      Grid.setItemRect(
          gridRef,
          cx,
          cy,
          cellSize,
          cellSize,
          id);

      editorState.itemTypeById
        .set(id, objectType);

      sendAction(localState, {
        type: 'PAINT_CELL',
        layerId: localState.activeLayerId,
        gridY: gridY,
      });
    };

    final removeSquare = (gridRef, gridX, gridY, width, height) -> {
      final cellSize = gridRef.cellSize;
      final cx = (gridX * cellSize) + (cellSize / 2);
      final cy = (gridY * cellSize) + (cellSize / 2);
      final items = Grid.getItemsInRect(
          gridRef,
          cx,
          cy,
          cellSize,
          cellSize);

      for (key in items) {
        Grid.removeItem(
            gridRef,
            key);
        editorState.itemTypeById.remove(key);
      }

      sendAction(localState, {
        type: 'CLEAR_CELL',
        layerId: localState.activeLayerId,
        gridY: gridY,
      });
    };

    final handleZoom = (e: hxd.Event) -> {
      if (e.kind == hxd.Event.EventKind.EWheel) {
        localState.zoom = Math.max(
            1, localState.zoom - Std.int(e.wheelDelta));
      }
    }
    Main.Global.staticScene.addEventListener(handleZoom);

    function toGridPos(gridRef, screenX: Float, screenY: Float) {
      final cellSize = gridRef.cellSize;
      final tx = editorState.translate.x;
      final ty = editorState.translate.y;
      final gridX = Math.floor((screenX - tx) / cellSize / localState.zoom);
      final gridY = Math.floor((screenY - ty) / cellSize / localState.zoom);

      return [gridX, gridY];
    }

    function updateObjectTypeList() {
      final win = hxd.Window.getInstance();
      var oy = 50;
      final itemSize = 50;
      final x = win.width - 200;
      final scale = 2;

      objectTypeMenu = [];

      for (type => meta in config.objectMetaByType) {
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
      isPanning = false;
      showObjectCenters = false;
      updateObjectTypeList();

      final activeGrid = editorState.gridByLayerId.get(
          localState.activeLayerId);
      final cellSize = activeGrid.cellSize;
      Main.Global.logData.activeLayer = localState.activeLayerId;

      {
        final tileRowsRedrawn: Map<String, Bool> = new Map();

        for (action in localState.actions) {
          switch (action.type) {
            case 'PAN_VIEWPORT':
              editorState.translate = action.translate;
            case
                'PAINT_CELL'
              | 'CLEAR_CELL'
              | 'PAINT_CELL_FROM_LOADING_STATE': {

                final activeGrid = editorState.gridByLayerId.get(
                    action.layerId);
                // [SIDE-EFFECT] creates a layer if it doesn't exist
                final activeTileRows = {
                  final activeLayerId = action.layerId;
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
                final rowId = '${action.layerId}__${rowIndex}';
                if (tileRowsRedrawn.get(rowId) == null) {
                  tileRowsRedrawn.set(rowId, true);
                  tg.clear();

                  final gridRow = Utils.withDefault(
                      activeGrid.data.get(rowIndex),
                      new Map());
                  // repaint row
                  for (colIndex => cellData in gridRow) {
                    for (itemId in cellData) {
                      final objectType = editorState.itemTypeById
                        .get(itemId);
                      final spriteKey = config.objectMetaByType
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
                          (colIndex * cellSize) + (cellSize / 2),
                          (rowIndex * cellSize) + (cellSize / 2),
                          tile);
                    }
                  }
                }
              }

            default: {}
          }

          if (action.type != 'PAINT_CELL_FROM_LOADING_STATE') {
            localState.stateToSave = editorState;
          }
        }

        // sort tilegroups by layer order and
        // row position so they draw properly
        for (layerId in editorState.layerOrderById) {
          final tRows = Utils.withDefault(
              localState.tileRowsByLayerId.get(layerId),
              new Map());
          final rowIndices = [];
          for (rowIndex in tRows.keys()) {
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
            final tileGroup = tRows.get(rowIndex);
            Main.Global.staticScene.addChild(
                tileGroup);
          }
        }

        // clear old actions list
        if (localState.actions.length > 0) {
          editorState.updatedAt = Date.now();
        }
        localState.actions = [];
      }

      Main.Global.logData.editor = {
        panning: isPanning,
        editorMode: Std.string(editorMode),
        updatedAt: editorState.updatedAt
      };

      final Key = hxd.Key;
      final buttonDown = Main.Global.worldMouse.buttonDown;
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
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

      if (localState.previousButtonDown != buttonDown) {
        localState.previousButtonDown = buttonDown;
        dragStartPos.x = Std.int(mx);
        dragStartPos.y = Std.int(my);
      }

      // handle grid interaction
      if (buttonDown == 0 && !isMenuItemHovered) {
        if (isPanning) {
          final dx = mx - dragStartPos.x;
          final dy = my - dragStartPos.y;

          sendAction(localState, {
            type: 'PAN_VIEWPORT',
            translate: {
              x: Std.int(translate.x + dx),
              y: Std.int(translate.y + dy),
            }
          });
          // handle grid update
        } else {
          final mouseGridPos = toGridPos(activeGrid, mx, my);
          final gridX = mouseGridPos[0];
          final gridY = mouseGridPos[1];

          switch (editorMode) {
            case EditorMode.Erase: {
              removeSquare(
                  activeGrid,
                  gridX,
                  gridY,
                  cellSize,
                  cellSize);
            }

            // replaces the cell with new value
            case EditorMode.Paint: {
              removeSquare(
                  activeGrid,
                  gridX,
                  gridY,
                  cellSize,
                  cellSize);

              insertSquare(
                  activeGrid,
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
          localState.zoom);
      Main.Global.staticScene.x = editorState.translate.x / localState.zoom;
      Main.Global.staticScene.y = editorState.translate.y / localState.zoom;

      return true;
    }

    function render(time) {
      final activeGrid = editorState.gridByLayerId
        .get(localState.activeLayerId);
      final cellSize = activeGrid.cellSize;
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
      final spriteEffectZoom = (p) -> {
        final b: h2d.SpriteBatch.BatchElement = p.batchElement;
        b.scale = localState.zoom;
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
          final spriteKey = config.objectMetaByType
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
        final spriteKey = config.objectMetaByType
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
            activeGrid,
            mx,
            my);
        final hc = cellSize / 2;
        sbs.emitSprite(
            (((mouseGridPos[0] * cellSize) + hc) * localState.zoom) +
            editorState.translate.x,
            (((mouseGridPos[1] * cellSize) + hc) * localState.zoom) +
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

    function paintTestItems() {
      for (rowIndex in 0...100) {
        for (colIndex in 0...400) {
          insertSquare(
              editorState.gridByLayerId.get(localState.activeLayerId),
              colIndex,
              rowIndex,
              Utils.uid(),
              'white_square');
        }
      }
    }

    Main.Global.updateHooks.push(update);
    Main.Global.renderHooks.push(render);
  }
}
