import Test;
import Fonts;

typedef GridKey = Int;

typedef GridRef = {
  var cellSize: Int;
  var data: Map<Int, Map<Int, Map<GridKey, GridKey>>>;
  var itemCache: Map<Int, Array<Int>>;
}

class GridExample extends h2d.Object {
  var ref: GridRef;
  var canvas: h2d.Graphics;
  var text: h2d.Text;
  var cellTile: h2d.Tile;
  var interactArea: h2d.Interactive;
  var cellSize = 64;
  var texture: h3d.mat.Texture;
  var cursorSize: Int;

  public function new(s2d: h2d.Scene) {
    super(s2d);

    cursorSize = cellSize * 2;
    texture = new h3d.mat.Texture(s2d.width, s2d.height, [h3d.mat.Data.TextureFlags.Target]);
    var tile = h2d.Tile.fromTexture(texture);

    cellTile = tile.sub(0, 0, cellSize, cellSize);
    canvas = new h2d.Graphics(this);
    canvas.beginFill(0xffffff, 0);
    canvas.lineStyle(1, 0xffffff);
    canvas.drawRect(0, 0, cellSize, cellSize);
    canvas.drawTo(texture);

    var cellFont = Fonts.primary.get().clone();
    cellFont.resizeTo(Math.round(12 * 1.5));
    text = new h2d.Text(cellFont, this);
    var textCanvas = new h2d.Graphics(this);
    var textTexture = new h3d.mat.Texture(
      s2d.width, s2d.height, [h3d.mat.Data.TextureFlags.Target]
    );
    var textTile = h2d.Tile.fromTexture(textTexture);

    function drawGridText(ref: Grid.GridRef) {
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

      text.text = '';

      for (t in tiles) {
        textCanvas.drawTile(
          t.x + cellSize / 2 - t.width / 2,
          t.y + cellSize / 2 - t.height / 2,
          t
        );
      }
    }

    ref = Grid.create(cellSize);

    interactArea = new h2d.Interactive(0, 0, Main.Global.rootScene);
    interactArea.enableRightButton = true;
    interactArea.onMove = function(ev: hxd.Event) {
      var mouseX = Math.round(ev.relX);
      var mouseY = Math.round(ev.relY);

      Grid.clear(ref);
      Grid.setItemRect(ref, mouseX, mouseY, cursorSize, cursorSize, 1);

      drawGridText(ref);
    }
  }

  public function update(dt: Float) {
    canvas.clear();
    interactArea.width = Main.Global.rootScene.width;
    interactArea.height = Main.Global.rootScene.height;

    for (y => row in ref.data) {
      for (x => items in row) {
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

  public static function test() {
    function numKeys(map: Map<Dynamic, Dynamic>) {
      var numKeys = 0;

      for (_ in map.keys()) {
        numKeys += 1;
      }

      return numKeys;
    }

    Test.assert('[grid] cell should have item', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;

      Grid.setItemRect(ref, 2, 3, 1, 1, itemKey);
      Grid.getCell(ref, 2, 3).exists(itemKey);
    });

    Test.assert('[grid] cell should remove item', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;

      Grid.setItemRect(ref, 2, 3, 1, 1, itemKey);
      Grid.removeItem(ref, itemKey);
      !Grid.getCell(ref, 2, 3).exists(itemKey);
    });

    Test.assert('[grid] move item', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;

      Grid.setItemRect(ref, 2, 3, 1, 1, itemKey);
      Grid.setItemRect(ref, 2, 4, 1, 1, itemKey);
      return numKeys(ref.data[3][2]) == 0 &&
        numKeys(ref.data[4][2]) == 1;
    });

    Test.assert('[grid] add item rect exact fit', () -> {
      var ref = Grid.create(1);
      var itemKey = 1;
      var width = 1;
      var height = 3;

      Grid.setItemRect(ref, 0, 1, width, height, itemKey);
      return numKeys(ref.data) == height &&
        numKeys(ref.data[0]) == width;
    });

    Test.assert('[grid] add item rect partial overlap', () -> {
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

    Test.assert('[grid] get items in rect', () -> {
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
