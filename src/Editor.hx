/*
 * NOTE: To keep things simple, we will only store one id
 * per object in the grid since we can derive all the
 * object information directly from that id. This way we're
 * not having to deal with varying issues around objects
 * changing their size because their position remains static.
 *
 * [ ] Optimize tile rendering so that it only renders what is in the viewport.
       We can do this for both the x and y axis, which should significantly
       cut down on the performance cost of rendering.
 * [ ] Ctrl-click to switch to layer that is under cursor.
       (This functions exactly like how Aseprite does it.)
 * [ ] Hold `s` and scroll wheel should cycle between the grid snapping options.
 * [ ] Show map object metadata when mouse cursor is near that object.
       This will be useful for those situations where you're trying
       to figure out exactly what that object was from, especially
       in cases where autotiling renders it differently.
       We can determine the bounding box of the object based on its
       sprite data. (source size, pivot, etc).
 * [ ] Add support for additional properties for an object. We can store this
       data on `editorState.itemPropertiesById`.  
   * [ ] Press `f` to flip brush horizontally, and `shift + f` to 
         flip brush vertically.
   * [ ] When copying/cutting/pasting, we need to also copy all other properties
         associated with that object.
   * [ ] Press `r` to rotate brush 45 degrees clockwise, 
         and `shift + r` to rotate brush 45 degrees counter-clockwise.
 * [ ] Minimap functionality. This will be useful for seeing a preview of the
       entire map while also surfacing any stray objects that we might not
       otherwise see because we forgot to clean them up.
 * [ ] [BUG] Fix issue with cursor brush in paint mode not properly snapping
       to the fine pixel grid. We can refer to the selected marquee 
       selection api since it doesn't appear to exhibit the same issues.
       to have this problem, so we can loo
 * [ ] undo/redo system
 * [ ] [BUG] Serializing state can sometimes crash.
       One possible cause is that we're mutating state while the
       thread is in mid-serialization. We need a better way of mutating
       state that doesn't interfere with the thread trying to access that
       at the same time.
 * [ ] State versioning so we can properly migrate data
 * [x] Controls for switching grid snapping sizes
 * [x] Custom grid snap size
 * [x] paint objects by placing them anywhere
 * [x] basic layer system
 * [x] load state from disk
 * [x] area selection cut/paste/delete
 * [x] improve zoom ux
 * [x] layer visibility toggling
 */

enum EditorMode {
  Panning;
  Paint;
  Erase;
  MarqueeSelect;
}

enum EditorUiRegion {
  MainMap;
  PaletteSelector;
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
typedef EditorState = {
  translate: {
    x: Int,
    y: Int,
  },
  updatedAt: Date,
  layerOrderById: Array<String>,
  gridByLayerId: Map<String, Grid.GridRef>,
  itemTypeById: Map<String, String>
};

typedef ConfigObjectMeta = {
  spriteKey: String,
  ?type: String,
  ?sharedId: String,
  ?ignoreRender: Bool,
  ?isAutoTile: Bool,
  ?autoTileCorner: Bool,
  ?alias: String,
}

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

class EditorTileGroup extends h2d.TileGroup {
  var shouldDraw: () -> Bool;

  public override function new(
      t : h2d.Tile,
      ?parent : h2d.Object,
      shouldDraw) {
    super(t, parent);
    this.shouldDraw = shouldDraw;
  }

  override function draw(ctx: h2d.RenderContext) {
    if (shouldDraw()) {
      super.draw(ctx);
    }
  }
}

class Editor {
  static final defaultObjectMeta = {
    spriteKey: 'ui/square_white',
    type: 'UNKNOWN_TYPE',
    sharedId: null,
    ignoreRender: false,
    isAutoTile: false,
    autoTileCorner: false,
    alias: 'UNKNOWN_ALIAS',
  };

  static function createObjectMeta(
      props: ConfigObjectMeta): ConfigObjectMeta {
    final newProps: ConfigObjectMeta = Reflect.copy(defaultObjectMeta);

    for (field in Reflect.fields(defaultObjectMeta)) {
      final defaultValue = Reflect.field(
          defaultObjectMeta, field);
      final propValue = Reflect.field(props, field);

      Reflect.setField(
          newProps, 
          field, 
          Utils.withDefault(
            propValue, defaultValue));
    }

    return newProps;
  }

  // all configuration stuff lives here
  public static final config: {
    activeFile: String,
    autoSave: Bool,
    objectMetaByType: Map<String, ConfigObjectMeta>,
    snapGridSizes: Array<Int>
  } = {
    // activeFile: 'editor-data/temp.eds',
    activeFile: 'editor-data/level_1.eds',
    autoSave: false,
    objectMetaByType: {
      final configList: Map<String, ConfigObjectMeta> = [
        'pillar' => {
          spriteKey: 'ui/pillar',
        },
        'player' => {
          spriteKey: 'player_animation/idle-0',
          // fixed id
          sharedId: 'playerStartPos'
        },
        'intro_level_boss' => {
          spriteKey: 'intro_boss_animation/idle-0'
        },
        'enemySpawnPoint' => {
          spriteKey: 'ui/enemy_spawn_point'
        },
        'teleporter' => {
          spriteKey: 'ui/teleporter_base',
        },
        'enemy_1' => {
          spriteKey: 'enemy-2_animation/idle-0',
        },
        'tile_1' => {
          spriteKey: 'ui/tile_1_1',
          type: 'traversableSpace',
          isAutoTile: true,
          autoTileCorner: true
        },
        'tile_1_detail_1' => {
          spriteKey: 'ui/tile_1_detail_1',
        },
        'tile_1_detail_2' => {
          spriteKey: 'ui/tile_1_detail_2',
          alias: 'alien_propulsion_booster'
        },
        'bridge_vertical' => {
          spriteKey: 'ui/bridge_vertical',
        }
      ];

      final metaByType = new Map<String, ConfigObjectMeta>();

      // add defaults
      for (key => config in configList) {
        metaByType.set(key, createObjectMeta(config));
      }

      metaByType;
    },
    snapGridSizes: [1, 8, 16]
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

  static var localState = null;
  // state to be serialized and saved
  static var editorState: EditorState;

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
    var finished = false;

    editorState = {
      final winCenter = windowCenterPos();
      final cellSize = 1;

      {
        translate: {
          x: Math.round(winCenter.x),
          y: Math.round(winCenter.y)
        },
        updatedAt: Date.now(),
        layerOrderById: [
          'layer_1',
          'layer_2',
          'layer_3',
          'layer_4',
          'layer_5',
          'layer_6',
          'layer_7',
          'layer_8',
          'layer_prefab',
          // this is just for the marquee selection
          // and should not be selectable
          'layer_marquee_selection',
        ],
        gridByLayerId: [
          'layer_1' => Grid.create(cellSize),
          'layer_2' => Grid.create(cellSize),
          'layer_3' => Grid.create(cellSize),
          'layer_4' => Grid.create(cellSize),
          'layer_5' => Grid.create(cellSize),
          'layer_6' => Grid.create(cellSize),
          'layer_7' => Grid.create(cellSize),
          'layer_8' => Grid.create(cellSize),
          'layer_prefab' => Grid.create(cellSize),
          'layer_marquee_selection' => Grid.create(cellSize),
        ],
        itemTypeById: new Map<String, String>()
      };
    }

    localState = {
      editorUiRegion: EditorUiRegion.MainMap,
      uiRegionRects: new Map<EditorUiRegion, h2d.col.Bounds>(),
      uiRegionState: [
        EditorUiRegion.PaletteSelector => {
          scrollY: 0
        }
      ],

      selectedObjectType: 'tile_1',

      isDragStart: initialLocalState().isDragStart,
      isDragging: initialLocalState().isDragging,
      isDragEnd: initialLocalState().isDragEnd,
      snapGridSize: config.snapGridSizes[2],

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

      zoom: 4.0,
      actions: new Array<EditorStateAction>(),
      stateToSave: null,
      showAllLayers: true,
      layersToShow: [],
      // set to first layer by default
      activeLayerId: editorState.layerOrderById[0],
      tileRowsByLayerId: new Map<
        String,
      Map<Int, h2d.TileGroup>
        >()
    };

    final cleanupFns = [];
    final profiler = Profiler.create();
    final spriteSheetTile =
      hxd.Res.sprite_sheet_png.toTile();
    final spriteSheetData = Utils.loadJsonFile(
        hxd.Res.sprite_sheet_json).frames;
    final sbs = new SpriteBatchSystem(
        Main.Global.uiRoot);
    final loadPath = config.activeFile;
    final s2d = Main.Global.staticScene;
    // custom transformation function to
    // modify the saved data.
    final migrateState = (state: EditorState) -> {
      return state;
    };

    SaveState.load(
        loadPath,
        false,
        (unserialized) -> {
          final transformed = migrateState(unserialized);

          if (transformed == null) {
            trace('[editor load] no data to load at `${loadPath}`');

            return;
          }

          editorState = transformed;

          // repaint items from old state
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

    final saveAsync = () -> {
      try {
        final interval = 1 / 10;
        var savePending = false;

        while (true) {

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
        }       
      } catch(err) {
        trace('[editor save error]', err.stack);
      }
    };

    sys.thread.Thread.create(saveAsync);

    final removeSquare = (
        gridRef, gridX, gridY, width, height, layerId) -> {
      if (localState.editorUiRegion != EditorUiRegion.MainMap) {
        return;
      }

      final cellSize = gridRef.cellSize;
      final cx = gridX;
      final cy = gridY;
      final items = Grid.getItemsInRect(
          gridRef,
          cx,
          cy,
          cellSize,
          cellSize);
      var isAutoTile = false;

      for (key in items) {
        Grid.removeItem(
            gridRef,
            key);
        final objectType = editorState.itemTypeById.get(key);
        final objectMeta = config.objectMetaByType.get(objectType); 
        isAutoTile = objectMeta.isAutoTile;
        editorState.itemTypeById.remove(key);
      }

      sendAction(localState, {
        type: 'CLEAR_CELL',
        layerId: layerId,
        gridY: gridY,
      });

      if (isAutoTile) {
        // refresh row above
        sendAction(localState, {
          type: 'REFRESH_ROW',
          layerId: layerId,
          gridY: gridY + localState.snapGridSize
        });

        // refresh row below
        sendAction(localState, {
          type: 'REFRESH_ROW',
          layerId: layerId,
          gridY: gridY - localState.snapGridSize
        });
      }
    };

    final insertSquare = (
        gridRef: Grid.GridRef, 
        gridX, gridY, id, objectType, layerId) -> {
      if (localState.editorUiRegion != EditorUiRegion.MainMap) {
        return;
      }

      final cellSize = gridRef.cellSize;
      final snapGridSize = localState.snapGridSize;
      final cx = gridX;
      final cy = gridY;
      final hasSharedId = editorState.itemTypeById.exists(id);

      // remove item that shares same id
      if (hasSharedId) {
        final bounds = gridRef.itemCache.get(id); 

        if (bounds != null) {
          final x = bounds[0];
          final y = bounds[2];

          removeSquare(
              gridRef,
              x, y,
              1, 1,
              layerId);
        }
      }

      // we want to replace the current cell value
      // with a new value
      removeSquare(
          gridRef,
          gridX,
          gridY,
          cellSize,
          cellSize,
          layerId);

      Grid.setItemRect(
          gridRef,
          cx,
          cy,
          1,
          1,
          id);

      editorState.itemTypeById
        .set(id, objectType);

      sendAction(localState, {
        type: 'PAINT_CELL',
        layerId: layerId,
        gridY: gridY,
      });

      final objectType = editorState.itemTypeById.get(id);
      final objectMeta = config.objectMetaByType.get(objectType); 

      if (objectMeta.isAutoTile) {
        // refresh row above
        sendAction(localState, {
          type: 'REFRESH_ROW',
          layerId: layerId,
          gridY: gridY + localState.snapGridSize
        });

        // refresh row below
        sendAction(localState, {
          type: 'REFRESH_ROW',
          layerId: layerId,
          gridY: gridY - localState.snapGridSize
        });
      }
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
      if (localState.editorUiRegion != EditorUiRegion.MainMap) {
        return;
      }

      if (e.kind == hxd.Event.EventKind.EWheel) {
        final currentZoom = localState.zoom;
        final nextZoom = Math.max(
            1, currentZoom - Std.int(e.wheelDelta));

        // translate so that it is zooming to cursor position
        {
          final win = hxd.Window.getInstance();
          final wmx = win.mouseX;
          final wmy = win.mouseY;
          final newTranslate = {
            x: Std.int(wmx / nextZoom
                   - (wmx / currentZoom - editorState.translate.x)),
            y: Std.int(wmy / nextZoom
                - (wmy / currentZoom - editorState.translate.y)),
          };

          editorState.translate = newTranslate;
        }

        localState.zoom = nextZoom;
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

    final handlePaletteMenu = (e: hxd.Event) -> {
      if (localState.editorUiRegion != EditorUiRegion.PaletteSelector) {
        return;
      }

      final action = {
        if (e.kind == hxd.Event.EventKind.EWheel) {
          'SCROLL';
        } else {
          'NONE';
        }
      }

      switch(action) {
        case 'SCROLL': {
          final state = localState.uiRegionState
            .get(EditorUiRegion.PaletteSelector);
          state.scrollY = Std.int(Math.min(0, state.scrollY + e.wheelDelta));
          return;
        }

        default: {}
      }
    };

    final listener = (e: hxd.Event) -> {
      for (fn in [
          handleZoom, 
          handleDrag, 
          handlePaletteMenu]) {
        fn(e);
      }
    };

    s2d.addEventListener(listener);
    cleanupFns.push(() -> {
      s2d.removeEventListener(listener);
      return;
    });

    function toGridPos(gridSize: Int, gridRef, screenX: Float, screenY: Float) {
      final tx = editorState.translate.x * localState.zoom;
      final ty = editorState.translate.y * localState.zoom;
      final hg = gridSize / 2;
      final gridX = Math.floor((screenX - tx) / gridSize / localState.zoom)
        * gridSize + hg;
      final gridY = Math.floor((screenY - ty) / gridSize / localState.zoom)
        * gridSize + hg;

      return [gridX, gridY];
    }

    function updateObjectMetaList() {
      final win = hxd.Window.getInstance();
      final itemSize = 100;
      final sidePadding = 20;
      final regionState = localState.uiRegionState
        .get(EditorUiRegion.PaletteSelector);
      final scrollSpeed = 50;
      var oy = itemSize + regionState.scrollY * scrollSpeed;
      final x = Std.int(win.width - itemSize / 2) - sidePadding;
      final itemSpacing = 10;
      final uiRect = new h2d.col.Bounds();
      uiRect.set(
          x - itemSize / 2 - sidePadding,
          0,
          itemSize + sidePadding * 2,
          win.height);
      localState.uiRegionRects.set(
          EditorUiRegion.PaletteSelector,
          uiRect);
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

    function createId(objectType) {
      final objectMeta = config.objectMetaByType.get(
          localState.selectedObjectType);

      final sharedId = objectMeta.sharedId;

      return sharedId == null 
        ? Utils.uid() : sharedId;
    }

    function update(dt) {
      if (!hxd.Window.getInstance().isFocused) {
        return !finished;
      }

      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;

      updateObjectMetaList();
      localState.editorUiRegion = {
        final p = new h2d.col.Point(mx, my);
        var activeRegion = EditorUiRegion.MainMap; 

        for (regionType => bounds in localState.uiRegionRects) {
          if (bounds.contains(p)) {
            activeRegion = regionType;
          }
        }

        activeRegion;
      };

      final activeGrid = editorState.gridByLayerId.get(
          localState.activeLayerId);
      final cellSize = localState.snapGridSize;

      function isTileItem(cellData) {
        return cellData != null;
      }

      {
        final tileRowsRedrawn: Map<String, Bool> = new Map();
        final currentActions = localState.actions;

        for (action in currentActions) {
          switch (action.type) {
            case 'PAN_VIEWPORT': {
              editorState.translate = action.translate;
            }
            case 'CLEAR_MARQUEE_SELECTION': {
            }
            case
                'PAINT_CELL'
              | 'CLEAR_CELL'
              | 'PAINT_CELL_FROM_LOADING_STATE'
              | 'REFRESH_ROW': {
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
                final rowIndex = action.gridY;
                final tg = {
                  final tg = activeTileRows.get(rowIndex);

                  if (tg == null) {
                    final isVisibleLayer = (layerId) ->
                      layerId == action.layerId;
                    final newTg = new EditorTileGroup(
                        spriteSheetTile,
                        Main.Global.staticScene,
                        () -> {
                          return Lambda.find(
                              localState.layersToShow,
                              isVisibleLayer) != null;
                        });
                    activeTileRows.set(rowIndex, newTg);
                    cleanupFns.push(() -> {
                      newTg.remove();
                      newTg.clear();
                    });
                    newTg;
                  } else {
                    tg;
                  }
                };

                // refresh tile row
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
                      final objectMeta = config.objectMetaByType
                        .get(objectType);
                      final spriteKey = {
                        if (objectMeta.isAutoTile) {
                          final gridRef = editorState.gridByLayerId
                            .get(action.layerId);
                          final tileValue = AutoTile.getValue(
                              gridRef,
                              colIndex,
                              rowIndex,
                              isTileItem,
                              16,
                              objectMeta.autoTileCorner);

                          'ui/tile_1_${tileValue}';
                        } else {

                          objectMeta.spriteKey;
                        }
                      }
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
                          colIndex,
                          rowIndex,
                          tile);
                    }
                  }
                }
              }

            default: {}
          }

          if (config.autoSave && 
              action.type != 'PAINT_CELL_FROM_LOADING_STATE') {
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
                  localState.snapGridSize * localState.zoom);
              final mx = Main.Global.uiRoot.mouseX;
              final my = Main.Global.uiRoot.mouseY;
              final snappedMousePos = snapToGrid(
                  (mx - editorState.translate.x * localState.zoom),
                  (my - editorState.translate.y * localState.zoom),
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
        activeUiRegion: Std.string(localState.editorUiRegion),
        activeLayerId: localState.activeLayerId,
        regionState: localState.uiRegionState.get(EditorUiRegion.PaletteSelector),
        showAllLayers: localState.showAllLayers,
        snapGridSize: localState.snapGridSize,
        editorMode: Std.string(localState.editorMode),
        zoom: localState.zoom,
        translate: editorState.translate,
        updatedAt: editorState.updatedAt,
      };

      final Key = hxd.Key;
      final buttonDown = Main.Global.worldMouse.buttonDown;
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

        // manually trigger a save
        if (Key.isDown(Key.CTRL) && Key.isPressed(Key.S)) {
          localState.stateToSave = editorState;
        }

        // toggle grid snap size
        if (Key.isPressed(Key.S)) {
          final snapOpts = config.snapGridSizes;
          final curSettingIndex = Lambda.findIndex(
              snapOpts,
              (gs) -> gs == localState.snapGridSize);
          // cycle to next
          final nextSetting = curSettingIndex + 1;
          final shouldResetToStart = 
            nextSetting > (snapOpts.length - 1);
          localState.snapGridSize = snapOpts[
            shouldResetToStart
              ? 0
              : nextSetting];
        }

        if (Key.isPressed(Key.ESCAPE)) {
          clearMarqueeSelection();
        }

        if (Key.isPressed(Key.M)) {
          localState.editorMode = EditorMode.MarqueeSelect;
        }

        if (Key.isPressed(Key.TAB)) {
          localState.showAllLayers = !localState.showAllLayers;
        }

        if (localState.editorMode == EditorMode.MarqueeSelect) {
          final action = {
            if (Key.isDown(Key.CTRL)) {
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
            final gridXMin = Std.int(xMin);
            final gridXMax = Std.int(xMax);
            final gridYMin = Std.int(yMin);
            final gridYMax = Std.int(yMax);

            clearMarqueeSelection();

            for (gridY in gridYMin...gridYMax) {
              for (gridX in gridXMin...gridXMax) {
                final cellData = Grid.getCell(activeGrid, gridX, gridY);

                if (cellData != null) {
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
                          createId(objectType),
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
              final tx = localState.translate.x * localState.zoom;
              final ty = localState.translate.y * localState.zoom;
              final zoom = localState.zoom;
              final snappedMousePos = snapToGrid(
                  Math.floor((mx - tx)),
                  Math.floor((my - ty)),
                  Std.int(localState.snapGridSize * zoom));

              insertSquare(
                  activeGrid,
                  cx + Std.int(snappedMousePos.x / zoom),
                  cy + Std.int(snappedMousePos.y / zoom),
                  createId(objectType),
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

        // switch layer
        {
          final layerKeys = [
            Key.NUMBER_1,
            Key.NUMBER_2,
            Key.NUMBER_3,
            Key.NUMBER_4,
            Key.NUMBER_5,
            Key.NUMBER_6,
            Key.NUMBER_7,
            Key.NUMBER_8,
            Key.NUMBER_9,
          ];
          for (i in 0...layerKeys.length) {
            final key = layerKeys[i];
            final isSelected = Key.isPressed(key);

            if (isSelected) {
              localState.activeLayerId =
                editorState.layerOrderById[i];
            }
          }
        }

        // pan viewport to origin (0, 0)
        if (Key.isPressed(Key.F)) {
          final winCenter = windowCenterPos();
          sendAction(localState, {
            type: 'PAN_VIEWPORT',
            translate: {
              x: Std.int(winCenter.x / localState.zoom),
              y: Std.int(winCenter.y / localState.zoom),
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
        final zoom = localState.zoom;
        final cellSize = localState.snapGridSize * zoom;
        final translate = localState.translate;
        final gridX = Math.round((mx - translate.x * zoom) / cellSize);
        final gridY = Math.round((my - translate.y * zoom) / cellSize);
        final x = Std.int((gridX * cellSize) / zoom);
        final y = Std.int((gridY * cellSize) / zoom);

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
              x: Std.int(localState.translate.x + dx / localState.zoom),
              y: Std.int(localState.translate.y + dy / localState.zoom),
            }
          });
          // handle grid update
        } else {
          final mouseGridPos = toGridPos(
              localState.snapGridSize, activeGrid, mx, my);
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
              insertSquare(
                  activeGrid,
                  gridX,
                  gridY,
                  createId(localState.selectedObjectType),
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

      // update layerVisibility
      {
        localState.layersToShow = {
          localState.showAllLayers
          ? editorState.layerOrderById
          : [
            localState.activeLayerId,
            'layer_marquee_selection',
            'layer_prefab'
          ];
        }
      }

      Main.Global.staticScene.scaleMode = ScaleMode.Zoom(
          localState.zoom);
      Main.Global.staticScene.x = editorState.translate.x;
      Main.Global.staticScene.y = editorState.translate.y;

      localState.isDragStart = initialLocalState().isDragStart;
      localState.isDragEnd = initialLocalState().isDragEnd;

      return !finished;
    }

    function render(time) {
      if (!hxd.Window.getInstance().isFocused) {
        return !finished;
      }

      final activeGrid = editorState.gridByLayerId
        .get(localState.activeLayerId);
      final cellSize = activeGrid.cellSize;
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
      final zoom = localState.zoom;
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
            final spriteMaxDimension = Math.max(
                spriteData.sourceSize.w,
                spriteData.sourceSize.h);
            Math.min(2, menuItem.height / spriteMaxDimension);
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

      {
        final snapGridSize = localState.snapGridSize;
        final mouseGridPos = toGridPos(
            snapGridSize,
            activeGrid,
            mx,
            my);
        final hc = snapGridSize / 2;
        final cx = (((mouseGridPos[0])) * localState.zoom) +
          editorState.translate.x * localState.zoom;
        final cy = (((mouseGridPos[1])) * localState.zoom) +
          editorState.translate.y * localState.zoom;

        // show active brush at cursor
        if (localState.editorMode == EditorMode.Paint) {
          final spriteKey = config.objectMetaByType
            .get(localState.selectedObjectType).spriteKey;
          sbs.emitSprite(
              cx, cy,
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

        // show hovered cell (rectangle) at cursor
        {
          final alpha = 0.8;
          final sortOrder = drawSortSelection + 1;
          // north edge
          sbs.emitSprite(
              cx - hc * zoom, cy - hc * zoom,
              'ui/square_white',
              null,
              (p) -> {
                final b: h2d.SpriteBatch.BatchElement =
                  p.batchElement;
                p.sortOrder = sortOrder;
                b.scaleX = snapGridSize * zoom;
                b.alpha = alpha;
              });

          // east edge
          sbs.emitSprite(
              cx + hc * zoom, cy - hc * zoom,
              'ui/square_white',
              null,
              (p) -> {
                final b: h2d.SpriteBatch.BatchElement =
                  p.batchElement;
                p.sortOrder = sortOrder;
                b.scaleY = snapGridSize * zoom;
                b.alpha = alpha;
              });

          // south edge
          sbs.emitSprite(
              cx - hc * zoom, cy + hc * zoom,
              'ui/square_white',
              null,
              (p) -> {
                final b: h2d.SpriteBatch.BatchElement =
                  p.batchElement;
                p.sortOrder = sortOrder;
                b.scaleX = snapGridSize * zoom;
                b.alpha = alpha;
              });

          // west edge
          sbs.emitSprite(
              cx - hc * zoom, cy - hc * zoom,
              'ui/square_white',
              null,
              (p) -> {
                final b: h2d.SpriteBatch.BatchElement =
                  p.batchElement;
                p.sortOrder = sortOrder;
                b.scaleY = snapGridSize * zoom;
                b.alpha = alpha;
              });
        }
      }

      // show origin
      {
        sbs.emitSprite(
            editorState.translate.x * localState.zoom,
            editorState.translate.y * localState.zoom,
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
        final zoom = localState.zoom;
        final tx = localState.translate.x * zoom;
        final ty = localState.translate.y * zoom;

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

      return !finished;
    }

    final backgroundRef = Game.makeBackground();
    cleanupFns.push(() -> backgroundRef.remove());

    Main.Global.updateHooks.push(update);
    Main.Global.renderHooks.push(render);

    return () -> {
      for (fn in cleanupFns) {
        fn();
      }

      finished = true;
    };
  }
}
