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
 * [ ] [WIP] area selection cut/paste/delete
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
  MarqueeSelect;
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
    activeFile: 'editor-data/level_1.eds',
    objectMetaByType: [
      'pillar' => {
        spriteKey: 'ui/pillar',
      },
      'enemy_1' => {
        spriteKey: 'enemy-2_animation/idle-0',
      },
      'tile_1' => {
        spriteKey: 'ui/level_1_tile',
      },
      'white_square' => {
        spriteKey: 'ui/square_tile_test',
      },
    ]
  }

  static var objectTypeMenu: Array<{
    x: Int,
    y: Int,
    width: Int,
    height: Int,
    type: String
  }> = [];

  static function initialLocalState() {
    return {
      isDragStart: false,
      isDragging: false,
      isDragEnd: false,

      marqueeSelection: {
        x1: 0,
        y1: 0,
        x2: 0,
        y2: 0
      }
    };
  }

  static var localState = {
    selectedObjectType: 'white_square',

    isDragStart: initialLocalState().isDragStart,
    isDragging: initialLocalState().isDragging,
    isDragEnd: initialLocalState().isDragEnd,

    dragStartPos: {
      x: 0,
      y: 0
    },
    translate: {
      x: 0,
      y: 0
    },
    marqueeSelection: initialLocalState()
      .marqueeSelection,

    editorMode: EditorMode.Paint,
    previousEditorMode: EditorMode.Paint,

    zoom: 2.0,
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
  static var editorState = null;

  // adds an action to the queue to be
  // processed on the next update loop
  static function sendAction(
      state: Dynamic,
      action: Dynamic) {
    state.actions.push(action);
  }

  static function windowCenterPos() {
    final win = hxd.Window.getInstance();

    return {
      x: Math.round(win.width / 2),
      y: Math.round(win.height / 2)
    }
  }

  public static function init() {
    editorState = {
      final winCenter = windowCenterPos();
      final cellSize = 16;

      {
        translate: {
          x: Math.round(winCenter.x),
          y: Math.round(winCenter.y)
        },
        updatedAt: Date.now(),
        layerOrderById: [
          'layer_a',
          'layer_b',
          'layer_marquee_selection',
        ],
        gridByLayerId: [
          'layer_a' => Grid.create(cellSize),
          'layer_b' => Grid.create(cellSize),
          'layer_marquee_selection' => Grid.create(cellSize),
        ],
        itemTypeById: new Map<String, String>()
      };
    }

    final profiler = Profiler.create();
    final spriteSheetTile =
      hxd.Res.sprite_sheet_png.toTile();
    final spriteSheetData = Utils.loadJsonFile(
        hxd.Res.sprite_sheet_json).frames;
    final sbs = new SpriteBatchSystem(
        Main.Global.uiRoot);
    final loadPath = config.activeFile;
    final s2d = Main.Global.staticScene;

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

    final insertSquare = (
        gridRef, gridX, gridY, id, objectType, layerId) -> {
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
        layerId: layerId,
        gridY: gridY,
      });
    };

    final removeSquare = (
        gridRef, gridX, gridY, width, height, layerId) -> {
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
        layerId: layerId,
        gridY: gridY,
      });
    };

    function clearMarqueeSelection() {
      final marqueeLayerId = 'layer_marquee_selection';
      final marqueeGrid = editorState.gridByLayerId
        .get(marqueeLayerId);

      for (_ => bounds in marqueeGrid.itemCache) {
        final width = bounds[1] - bounds[0];
        final cx = Math.floor(bounds[0] + width / 2);
        final height = bounds[3] - bounds[2];
        final cy = Math.floor(bounds[2] + height / 2);

        removeSquare(
            marqueeGrid,
            cx,
            cy,
            width,
            height,
            marqueeLayerId);
      }

      // also reset rectangle selection area
      localState.marqueeSelection = initialLocalState()
        .marqueeSelection;
    }

    final handleZoom = (e: hxd.Event) -> {
      if (e.kind == hxd.Event.EventKind.EWheel) {
        localState.zoom = Math.max(
            1, localState.zoom - Std.int(e.wheelDelta));
      }
    }

    final handleDrag = (e: hxd.Event) -> {
      if (e.kind == hxd.Event.EventKind.EPush) {
        localState.isDragStart = true;
        localState.isDragging = true;
      }

      if (e.kind == hxd.Event.EventKind.ERelease) {
        localState.isDragEnd = true;
        localState.isDragging = false;
      }
    }
    s2d.addEventListener(handleZoom);
    s2d.addEventListener(handleDrag);

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
      final itemSize = 100;
      var oy = itemSize;
      final x = win.width - itemSize - 10;
      final itemSpacing = 10;

      objectTypeMenu = [];

      for (type => meta in config.objectMetaByType) {
        objectTypeMenu.push({
          x: x,
          y: oy,
          width: itemSize,
          height: itemSize,
          type: type,
        });

        oy += (itemSize + itemSpacing);
      }
    }

    function update(dt) {
      updateObjectTypeList();

      final activeGrid = editorState.gridByLayerId.get(
          localState.activeLayerId);
      final cellSize = activeGrid.cellSize;
      Main.Global.logData.activeLayer = localState.activeLayerId;

      {
        final tileRowsRedrawn: Map<String, Bool> = new Map();

        for (action in localState.actions) {
          switch (action.type) {
            case 'PAN_VIEWPORT': {
              editorState.translate = action.translate;
            }
            case 'CLEAR_MARQUEE_SELECTION': {
            }
            case
                'PAINT_CELL'
              | 'CLEAR_CELL'
              | 'PAINT_CELL_FROM_LOADING_STATE': {

                final activeGrid = editorState.gridByLayerId.get(
                    action.layerId);
                // [SIDE-EFFECT] creates a tileGroup if it doesn't exist
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

                  if (action.layerId == 'layer_marquee_selection') {
                    tg.setDefaultColor(0xffffff, 0.4);
                  }

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

            // move marquee selection relative to mouse position
            if (layerId == 'layer_marquee_selection') {
              final snapToGrid = (x: Float, y: Float, cellSize) -> {
                final gridX = Math.round(x / cellSize);
                final gridY = Math.round(y / cellSize);
                final x = Std.int(gridX * cellSize);
                final y = Std.int(gridY * cellSize);

                return {
                  x: x,
                  y: y
                };
              }

              final marqueeGrid = editorState.gridByLayerId
                .get('layer_marquee_selection');
              final cellSize = Std.int(
                  marqueeGrid.cellSize * localState.zoom);
              final mx = Main.Global.uiRoot.mouseX;
              final my = Main.Global.uiRoot.mouseY;
              final snappedMousePos = snapToGrid(
                  (mx - editorState.translate.x),
                  (my - editorState.translate.y),
                  cellSize);

              tileGroup.x = snappedMousePos.x / localState.zoom;
              tileGroup.y = snappedMousePos.y / localState.zoom;
            }
          }
        }

        // clear old actions list
        if (localState.actions.length > 0) {
          editorState.updatedAt = Date.now();
        }
        localState.actions = [];
      }

      Main.Global.logData.editor = {
        translate: editorState.translate,
        editorMode: Std.string(localState.editorMode),
        marqueeSelection: localState.marqueeSelection,
        updatedAt: editorState.updatedAt,
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
        localState.selectedObjectType = menuItemHovered.value;
      }

      // handle hotkeys
      {
        // toggle panning mode
        {
          if (Key.isDown(Key.SPACE) && 
              localState.editorMode != EditorMode.Panning) {
            localState.previousEditorMode = localState.editorMode;
            localState.editorMode = EditorMode.Panning;
          }

          if (Key.isReleased(Key.SPACE) && 
              localState.editorMode == EditorMode.Panning) {
            localState.editorMode = localState.previousEditorMode;
          }
        }

        if (Key.isPressed(Key.M)) {
          localState.editorMode = EditorMode.MarqueeSelect;
        }

        if (localState.editorMode == EditorMode.MarqueeSelect) {
          final action = {
            if (Key.isPressed(Key.ESCAPE)) {

              'CLEAR_MARQUEE_SELECTION';

            } else if (Key.isDown(Key.CTRL)) {
              if (Key.isPressed(Key.C)) {
                'COPY';
              }

              else if (Key.isPressed(Key.X)) {
                'CUT';
              }

              else if (Key.isPressed(Key.V)) {
                'PASTE';
              } else {

                'NONE';
              }

            } else if (Key.isPressed(Key.DELETE)) {

              'DELETE';

            } else {

              'NONE';

            }
          };

          if (action == 'CLEAR_MARQUEE_SELECTION') {
            clearMarqueeSelection();
          }

          final marqueeLayerId = 'layer_marquee_selection';
          final marqueeGrid = editorState.gridByLayerId
            .get(marqueeLayerId);

          // copy selection
          if (action == 'COPY' || action == 'CUT' || action == 'DELETE') {
            final activeGrid = editorState.gridByLayerId
              .get(localState.activeLayerId);
            final selection = localState.marqueeSelection;
            final xMin = Math.min(
                selection.x1, 
                selection.x2);
            final xMax = Math.max(
                selection.x1, 
                selection.x2);
            final yMin = Math.min(
                selection.y1, 
                selection.y2);
            final yMax = Math.max(
                selection.y1, 
                selection.y2);
            final gridXMin = Math.floor(xMin / marqueeGrid.cellSize);
            final gridXMax = Math.floor(xMax / marqueeGrid.cellSize);
            final gridYMin = Math.floor(yMin / marqueeGrid.cellSize);
            final gridYMax = Math.floor(yMax / marqueeGrid.cellSize);

            clearMarqueeSelection();

            for (gridY in gridYMin...gridYMax) {
              for (gridX in gridXMin...gridXMax) {
                final cellData = Utils.withDefault(
                    Grid.getCell(activeGrid, gridX, gridY),
                    new Map());
                for (itemId in cellData) {
                  final objectType = editorState.itemTypeById.get(
                      itemId);

                  // copy selection to 'clipboard'
                  if (action == 'CUT' || action == 'COPY') {
                    insertSquare(
                        marqueeGrid,
                        // insert relative to 0,0 of marqueeGrid
                        gridX - gridXMin,
                        gridY - gridYMin,
                        Utils.uid(),
                        objectType,
                        marqueeLayerId);
                  }

                  if (action == 'CUT' || action == 'DELETE') {
                    removeSquare(
                        activeGrid,
                        gridX,
                        gridY,
                        activeGrid.cellSize,
                        activeGrid.cellSize,
                        localState.activeLayerId);
                  }
                }
              }
            }
          }

          // paste selection
          if (action == 'PASTE') {
            final snapToGrid = (x, y, cellSize) -> {
              final gridX = Math.round(x / cellSize);
              final gridY = Math.round(y / cellSize);
              final x = Std.int(gridX * cellSize);
              final y = Std.int(gridY * cellSize);

              return {
                x: x,
                y: y
              };
            }

            for (itemId => bounds in marqueeGrid.itemCache) {
              final width = bounds[1] - bounds[0];
              final cx = Math.floor(bounds[0] + width / 2);
              final height = bounds[3] - bounds[2];
              final cy = Math.floor(bounds[2] + height / 2);
              final objectType = editorState.itemTypeById.get(
                  itemId);
              final activeGrid = editorState.gridByLayerId
                .get(localState.activeLayerId);
              final mx = Main.Global.uiRoot.mouseX;
              final my = Main.Global.uiRoot.mouseY;
              final tx = localState.translate.x;
              final ty = localState.translate.y;
              final zoom = localState.zoom;
              final snappedMousePos = snapToGrid(
                  Math.floor((mx - tx)),
                  Math.floor((my - ty)),
                  Std.int(marqueeGrid.cellSize * zoom));

              insertSquare(
                  activeGrid,
                  cx + Std.int(snappedMousePos.x / cellSize / zoom),
                  cy + Std.int(snappedMousePos.y / cellSize / zoom),
                  Utils.uid(),
                  objectType,
                  localState.activeLayerId);
            }
          }
        }

        if (Key.isPressed(Key.E)) {
          localState.editorMode = EditorMode.Erase;
        }

        if (Key.isPressed(Key.B)) {
          localState.editorMode = EditorMode.Paint;
        }

        if (Key.isPressed(Key.NUMBER_1)) {
          localState.activeLayerId = 'layer_a';
        }

        if (Key.isPressed(Key.NUMBER_2)) {
          localState.activeLayerId = 'layer_b';
        }

        // pan viewport to center of screen
        if (Key.isPressed(Key.F)) {
          final winCenter = windowCenterPos();
          sendAction(localState, {
            type: 'PAN_VIEWPORT',
            translate: {
              x: Std.int(winCenter.x),
              y: Std.int(winCenter.y),
            }
          });
        }
      }

      if (localState.isDragStart) {
        final dragStartX = Std.int(mx);
        final dragStartY = Std.int(my);

        localState.dragStartPos.x = dragStartX;
        localState.dragStartPos.y = dragStartY;
      }


      // handle marquee selection via mouse drag
      if (localState.editorMode == EditorMode.MarqueeSelect) {
        final cellSize = editorState.gridByLayerId
          .get(localState.activeLayerId).cellSize * localState.zoom;
        final gridX = Math.round((mx - localState.translate.x) / cellSize);
        final gridY = Math.round((my - localState.translate.y) / cellSize);
        final x = Std.int((gridX * cellSize) / localState.zoom);
        final y = Std.int((gridY * cellSize) / localState.zoom);

        if (localState.isDragStart) {
          localState.marqueeSelection.x1 = x;
          localState.marqueeSelection.y1 = y;
        }

        if (localState.isDragging) {
          localState.marqueeSelection.x2 = x;
          localState.marqueeSelection.y2 = y;
        }
      }

      // handle mouse button interaction
      if (buttonDown == 0 && !isMenuItemHovered) {
        if (localState.editorMode == EditorMode.Panning) {
          final dx = mx - localState.dragStartPos.x;
          final dy = my - localState.dragStartPos.y;

          sendAction(localState, {
            type: 'PAN_VIEWPORT',
            translate: {
              x: Std.int(localState.translate.x + dx),
              y: Std.int(localState.translate.y + dy),
            }
          });
          // handle grid update
        } else {
          final mouseGridPos = toGridPos(activeGrid, mx, my);
          final gridX = mouseGridPos[0];
          final gridY = mouseGridPos[1];

          switch (localState.editorMode) {
            case EditorMode.Erase: {
              removeSquare(
                  activeGrid,
                  gridX,
                  gridY,
                  cellSize,
                  cellSize,
                  localState.activeLayerId);
            }

            // replaces the cell with new value
            case EditorMode.Paint: {
              removeSquare(
                  activeGrid,
                  gridX,
                  gridY,
                  cellSize,
                  cellSize,
                  localState.activeLayerId);

              insertSquare(
                  activeGrid,
                  gridX,
                  gridY,
                  Utils.uid(),
                  localState.selectedObjectType,
                  localState.activeLayerId);
            }

            default: {}
          }
        }
      } else {
        localState.translate.x = editorState.translate.x;
        localState.translate.y = editorState.translate.y;
      }

      Main.Global.staticScene.scaleMode = ScaleMode.Zoom(
          localState.zoom);
      Main.Global.staticScene.x = editorState.translate.x / localState.zoom;
      Main.Global.staticScene.y = editorState.translate.y / localState.zoom;

      localState.isDragStart = initialLocalState().isDragStart;
      localState.isDragEnd = initialLocalState().isDragEnd;

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
        for (menuItem in objectTypeMenu) {
          final spriteData = Reflect.field(
              spriteSheetData,
              config.objectMetaByType.get(menuItem.type)
              .spriteKey);
          final scale = {
            final spriteHeight = spriteData.sourceSize.h;
            menuItem.height / spriteHeight;
          }
          final spriteEffect = (p) -> {
            final b: h2d.SpriteBatch.BatchElement = p.batchElement;
            b.scale = scale;
          };

          final spriteKey = config.objectMetaByType
            .get(menuItem.type)
            .spriteKey;
          sbs.emitSprite(
              menuItem.x,
              menuItem.y,
              spriteKey,
              null,
              spriteEffect);
        }
      }

      final drawSortSelection = 1000 * 1000;
      // show selection at cursor
      if (localState.editorMode == EditorMode.Paint) {
        final spriteKey = config.objectMetaByType
          .get(localState.selectedObjectType).spriteKey;
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

      // show origin
      {
        sbs.emitSprite(
            editorState.translate.x,
            editorState.translate.y,
            'ui/square_white',
            null,
            (p) -> {
              final b: h2d.SpriteBatch.BatchElement =
                p.batchElement;
              b.scale = 10; 
              p.sortOrder = drawSortSelection + 1;
              b.b = 0.4;
              b.alpha = 0.6;
            });
      }

      // render marquee selection rectangle
      if (localState.editorMode == EditorMode.MarqueeSelect) {
        final selection = localState.marqueeSelection;
        final tx = localState.translate.x;
        final ty = localState.translate.y;
        final zoom = localState.zoom;

        sbs.emitSprite(
            (Math.min(selection.x1, selection.x2)) * zoom + tx,
            (Math.min(selection.y1, selection.y2)) * zoom + ty,
            'ui/square_white',
            null,
            (p) -> {
              final b: h2d.SpriteBatch.BatchElement =
                p.batchElement;
              b.scaleX = Math.abs(selection.x1 - selection.x2) * zoom; 
              b.scaleY = Math.abs(selection.y1 - selection.y2) * zoom; 
              p.sortOrder = drawSortSelection + 2;
              b.b = 0.4;
              b.alpha = 0.3;
            });
      }

      return true;
    }

    Main.Global.updateHooks.push(update);
    Main.Global.renderHooks.push(render);
  }
}
