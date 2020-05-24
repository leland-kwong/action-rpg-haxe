import hxd.Key;
import TestUtils.assert;
import Fonts;
import SaveState;

typedef GridKey = Int;

typedef GridRef = {
  var cellSize: Int;
  var data: Map<Int, Map<Int, Map<GridKey, GridKey>>>;
  var itemCache: Map<Int, Array<Int>>;
}

enum GridEditMode {
  Normal;
  Insert;
  Delete;
}

class GridExample {
  var mouseGridRef: GridRef;
  var environmentGridRef: GridRef;
  var canvas: h2d.Graphics;
  var text: h2d.Text;
  var cellTile: h2d.Tile;
  var interactArea: h2d.Interactive;
  var cellSize = 64;
  var texture: h3d.mat.Texture;
  var cursorSize: Int;
  var debugPoint: h2d.Graphics;
  var scene: h2d.Scene;
  var editMode: GridEditMode;
  var updateGrids: (ev: {relX: Float, relY: Float}) -> Void;

  public function new(s2d: h2d.Scene) {
    SaveState.tests();

    scene = s2d;
    {
      debugPoint = new h2d.Graphics(s2d);
      debugPoint.beginFill(Game.Colors.yellow);
      debugPoint.drawCircle(0, 0, 10);
    }
    cursorSize = cellSize;
    texture = new h3d.mat.Texture(s2d.width, s2d.height, [h3d.mat.Data.TextureFlags.Target]);
    var tile = h2d.Tile.fromTexture(texture);

    cellTile = tile.sub(0, 0, cellSize, cellSize);
    canvas = new h2d.Graphics(s2d);
    canvas.beginFill(0xffffff, 0);
    canvas.lineStyle(1, 0xffffff);
    canvas.drawRect(0, 0, cellSize, cellSize);
    canvas.drawTo(texture);

    var cellFont = Fonts.primary.get().clone();
    cellFont.resizeTo(Math.round(12 * 1.5));
    text = new h2d.Text(cellFont, s2d);
    var textCanvas = new h2d.Graphics(s2d);
    var textTexture = new h3d.mat.Texture(
      s2d.width, s2d.height, [h3d.mat.Data.TextureFlags.Target]
    );
    var textTile = h2d.Tile.fromTexture(textTexture);

    function drawGridInfo(ref: Grid.GridRef) {
      textTexture.clear(0xffffff, 0);
      textCanvas.clear();
      var tiles = [];

      for (y => row in ref.data) {
        for (x => cellData in row) {
          text.x = x * cellSize;
          text.y = y * cellSize;

          var numKeys = 0;
          for (_ in cellData.keys()) {
            numKeys += 1;
          }
          text.text = '${numKeys}';
          // text.textAlign = Center;
          text.drawTo(textTexture);
          tiles.push(
            textTile.sub(
              text.x,
              text.y,
              text.textWidth,
              text.textHeight
            )
          );
        }
      }

      // text.text = '';

      textCanvas.alpha = 0.5;
      for (t in tiles) {
        textCanvas.drawTile(
          t.x + cellSize / 2 - t.width / 2,
          t.y + cellSize / 2 - t.height / 2,
          t
        );
      }
    }

    mouseGridRef = Grid.create(cellSize);
    environmentGridRef = Grid.create(cellSize);

    interactArea = new h2d.Interactive(0, 0, Main.Global.rootScene);
    interactArea.enableRightButton = true;

    function editEnvironment(ev, editMode) {
      if (editMode == GridEditMode.Normal) {
        return;
      }

      var mouseX = Math.round(ev.relX);
      var mouseY = Math.round(ev.relY);
      var gridX = Grid.snapPosition(ev.relX, cursorSize);
      var gridY = Grid.snapPosition(ev.relY, cursorSize);

      // add item
      if (editMode == GridEditMode.Insert) {
        // remove previous items
        var currentItems = Grid.getItemsInRect(
          environmentGridRef, gridX, gridY, cursorSize, cursorSize
        );
        for (itemKey in currentItems) {
          Grid.removeItem(environmentGridRef, itemKey);
        }

        // add new wall
        var wallId = Utils.uid();
        Grid.setItemRect(environmentGridRef, gridX, gridY, cursorSize, cursorSize, wallId);
      }

      // remove item
      if (editMode == GridEditMode.Delete) {
        var items = Grid.getItemsInRect(environmentGridRef, gridX, gridY, cursorSize, cursorSize);
        for (key in items) {
          Grid.removeItem(environmentGridRef, key);
        }
      }
    }

    function previewInsertArea(ev) {
      var gridX = Grid.snapPosition(ev.relX, cursorSize);
      var gridY = Grid.snapPosition(ev.relY, cursorSize);

      Grid.clear(mouseGridRef);
      Grid.setItemRect(mouseGridRef, gridX, gridY, cursorSize, cursorSize, 1);

      drawGridInfo(mouseGridRef);
    }
    updateGrids = function(ev) {
      previewInsertArea(ev);
      editEnvironment(ev, editMode);
    };

    function setEditMode(ev: hxd.Event) {
      if (ev.button == 0) {
        editMode = GridEditMode.Insert;
      }

      if (ev.button == 1) {
        editMode = GridEditMode.Delete;
      }
    }
    interactArea.onPush = setEditMode;

    function setNormalMode(ev: hxd.Event) {
      editMode = GridEditMode.Normal;
    }
    interactArea.onRelease = setNormalMode;
  }

  public function update(dt: Float) {
    canvas.clear();
    interactArea.width = Main.Global.rootScene.width;
    interactArea.height = Main.Global.rootScene.height;

    updateGrids({
      relX: scene.mouseX,
      relY: scene.mouseY
    });

    {
      var gridX = Grid.snapPosition(scene.mouseX, cursorSize);
      var gridY = Grid.snapPosition(scene.mouseY, cursorSize);

      debugPoint.x = gridX;
      debugPoint.y = gridY;

      // toggle cursor size
      if (Key.isPressed(Key.T)) {
        cursorSize = cursorSize == cellSize
          ? cellSize * 2 : cellSize;
      }
    }

    // render grid
    for (gridRef in [mouseGridRef, environmentGridRef]) {
      for (y => row in gridRef.data) {
        for (x => items in row) {
          if (Utils.iterLength(items) == 0) {
            continue;
          }

          canvas.beginFill(Game.Colors.pureWhite, 0);
          canvas.lineStyle(1, Game.Colors.pureWhite);
          canvas.drawRect(
            x * cellTile.width,
            y * cellTile.height,
            cellTile.width,
            cellTile.height
          );
        }
      }
    }

    {
      var mouseX = Main.Global.rootScene.mouseX;
      var mouseY = Main.Global.rootScene.mouseY;
      canvas.beginFill(Game.Colors.yellow, 0);
      canvas.lineStyle(1, Game.Colors.yellow);
      canvas.drawRect(
        // snap to grid
        mouseX - cursorSize / 2,
        mouseY - cursorSize / 2,
        cursorSize,
        cursorSize
      );
    }
  }
}

class Grid {
  // snaps to the center of a cell
  public static function snapPosition(v: Dynamic, cellSize) {
    return Math.ceil(v / cellSize) * cellSize - Math.floor(cellSize / 2);
  }

  public static function create(cellSize): GridRef {
    return {
      cellSize: cellSize,
      data: new Map(),
      itemCache: new Map(),
    }
  }

  public static function clear(ref: GridRef) {
    ref.data.clear();
  }

  public static function getCell(ref: GridRef, x, y) {
    var row = ref.data[y];

    return row != null ? row[x] : null;
  }

  static function addItem(ref: GridRef, x, y, key: GridKey) {
    if (!ref.data.exists(y)) {
      ref.data[y] = new Map();
    }

    if (!ref.data[y].exists(x)) {
      ref.data[y][x] = new Map();
    }

    ref.data[y][x][key] = key;
  }

  // NOTE: origin is at center of rect
  public static function setItemRect(ref: GridRef, x, y, w, h, key: GridKey) {
    removeItem(ref, key);

    var xMin = Math.floor(Math.round(x - (w / 2)) / ref.cellSize);
    var xMax = Math.ceil(Math.round(x + (w / 2)) / ref.cellSize);
    var yMin = Math.floor(Math.round(y - (h / 2)) / ref.cellSize);
    var yMax = Math.ceil(Math.round(y + (h / 2)) / ref.cellSize);

    ref.itemCache[key] = [xMin, xMax, yMin, yMax];

    for (y in yMin...yMax) {
      for (x in xMin...xMax) {
        addItem(ref, x, y, key);
      }
    }
  }

  public static function getItemsInRect(ref: GridRef, x, y, w, h) {
    var xMin = Math.floor(Math.round(x - (w / 2)) / ref.cellSize);
    var xMax = Math.ceil(Math.round(x + (w / 2)) / ref.cellSize);
    var yMin = Math.floor(Math.round(y - (h / 2)) / ref.cellSize);
    var yMax = Math.ceil(Math.round(y + (h / 2)) / ref.cellSize);
    var items = new Map();

    for (y in yMin...yMax) {
      for (x in xMin...xMax) {
        var cellData = getCell(ref, x, y);
        if (cellData != null) {
          for (it in cellData) {
            items[it] = it;
          }
        }
      }
    }

    return items;
  }

  public static function removeItem(ref: GridRef, key: GridKey) {
    var cache = ref.itemCache[key];

    if (cache == null) {
      return;
    }

    var xMin = cache[0];
    var xMax = cache[1];
    var yMin = cache[2];
    var yMax = cache[3];

    for (y in yMin...yMax) {
      for (x in xMin...xMax) {
        var cellData = getCell(ref, x, y);

        if (cellData != null) {
          cellData.remove(key);
        }
      }
    }
  }

  public static function tests() {
    function numKeys(map: Map<Dynamic, Dynamic>) {
      var numKeys = 0;

      for (_ in map.keys()) {
        numKeys += 1;
      }

      return numKeys;
    }

    assert('[grid] cell should have item', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;

      Grid.setItemRect(ref, 2, 3, 1, 1, itemKey);
      Grid.getCell(ref, 2, 3).exists(itemKey);
    });

    assert('[grid] cell should remove item', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;

      Grid.setItemRect(ref, 2, 3, 1, 1, itemKey);
      Grid.removeItem(ref, itemKey);
      !Grid.getCell(ref, 2, 3).exists(itemKey);
    });

    assert('[grid] move item', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;

      Grid.setItemRect(ref, 2, 3, 1, 1, itemKey);
      Grid.setItemRect(ref, 2, 4, 1, 1, itemKey);
      return numKeys(ref.data[3][2]) == 0 &&
        numKeys(ref.data[4][2]) == 1;
    });

    assert('[grid] add item rect exact fit', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;
      var width = 1;
      var height = 3;

      Grid.setItemRect(ref, 0, 1, width, height, itemKey);
      return numKeys(ref.data) == height &&
        numKeys(ref.data[0]) == width;
    });

    assert('[grid] add item rect partial overlap', () -> {
      var cellSize = 10;
      var ref = Grid.create(cellSize);
      var itemKey = 1;
      var width = cellSize - 1;
      var height = cellSize - 1;

      Grid.setItemRect(
        ref,
        Math.round(width / 2) + 2,
        Math.round(height / 2) + 2,
        width,
        height,
        itemKey
      );

      return numKeys(ref.data) == Math.ceil(cellSize / height) &&
        numKeys(ref.data[0]) == Math.ceil(cellSize / width);
    });

    assert('[grid] get items in rect', () -> {
      var cellSize = 1;
      var ref = Grid.create(cellSize);
      var width = 2;
      var height = 2;
      var index = 0;

      for (y in 0...(height)) {
        for (x in 0...(width)) {
          Grid.setItemRect(ref, x, y, 1, 1, index);
          index += 1;
        }
      }

      var queryX = Math.round(width / 2);
      var queryY = Math.round(height / 2);

      return numKeys(
        Grid.getItemsInRect(ref, queryX, queryY, width, height)
      ) == 4;
    });
  }
}
