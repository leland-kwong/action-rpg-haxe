import hxd.Key;
import TestUtils.assert;
import Fonts;
import SaveState;
using StringTools;

typedef GridKey = String;
typedef GridItems = Map<GridKey, GridKey>;

typedef GridRef = {
  var cellSize: Int;
  var data: Map<
    Int, // row-index
    Map< // row-data
      Int, // column-index
      GridItems
    >
  >;
  var itemCache: Map<GridKey, Array<Int>>;
  var type: String;
  var pruneEmptyCell: Bool;
}

class Grid {
  // snaps to the center of a cell
  public static function snapPosition(
      v: Dynamic, cellSize) {
    return Math.ceil(v / cellSize) 
      * cellSize - Math.floor(cellSize / 2);
  }

  public static function create(
    cellSize,
    // Automatically cleans up empty rows and cells after each item removal.
    // This is necessary to prevent empty data structures from being serialized.
    pruneEmptyCell = true
  ): GridRef {
    return {
      cellSize: cellSize,
      data: new Map(),
      itemCache: new Map(),
      pruneEmptyCell: pruneEmptyCell,
      type: 'Grid'
    }
  }

  public static function has(
      ref: GridRef, key: GridKey) {
    return ref.itemCache.exists(key);
  }

  public static function isEmptyCell(
      ref: GridRef, x, y) {
    var cellData = getCell(ref, x, y);

    if (cellData == null) {
      return true;
    }

    return Lambda.count(cellData) == 0;
  }

  inline public static function getCell(
      ref: GridRef, x, y) {
    var row = ref.data[y];

    return row != null ? row[x] : null;
  }

  static function addItem(
      ref: GridRef, x, y, key: GridKey) {
    var curRow = ref.data[y];
    ref.data[y] = curRow == null 
      ? new Map() : curRow;
    var curCell = ref.data[y][x];
    ref.data[y][x] = curCell == null 
      ? new Map() : curCell;
    ref.data[y][x][key] = key;
  }

  // NOTE: origin is at center of rect
  public static function setItemRect(
    ref: GridRef,
    x: Float,
    y: Float,
    w: Int,
    h: Int,
    key: GridKey
  ) {
    var fromCache = ref.itemCache[key];
    var xMin = Math.floor(
        Math.round(x - (w / 2)) / ref.cellSize);
    var xMax = Math.ceil(
        Math.round(x + (w / 2)) / ref.cellSize);
    var yMin = Math.floor(
        Math.round(y - (h / 2)) / ref.cellSize);
    var yMax = Math.ceil(
        Math.round(y + (h / 2)) / ref.cellSize);

    if (
      fromCache != null
      && xMin == fromCache[0]
      && xMax == fromCache[1]
      && yMin == fromCache[2]
      && yMax == fromCache[3]
    ) {
      return;
    }

    removeItem(ref, key);
    ref.itemCache[key] = [xMin, xMax, yMin, yMax];

    for (_y in yMin...yMax) {
      for (_x in xMin...xMax) {
        addItem(ref, _x, _y, key);
      }
    }
  }

  public static function getItemsInRect(
      ref: GridRef, x: Float, y: Float, w, h) {
    var xMin = Math.floor(
        Math.round(x - (w / 2)) / ref.cellSize);
    var xMax = Math.ceil(
        Math.round(x + (w / 2)) / ref.cellSize);
    var yMin = Math.floor(
        Math.round(y - (h / 2)) / ref.cellSize);
    var yMax = Math.ceil(
        Math.round(y + (h / 2)) / ref.cellSize);
    var items: GridItems = new Map();

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

  public static function eachCell(
      ref: GridRef, callback) {
    for (y => row in ref.data) {
      for (x => items in row) {
        callback(x, y, items);
      }
    }
  }

  public static function removeItem(
      ref: GridRef, key: GridKey) {
    var cache = ref.itemCache[key];

    if (cache == null) {
      return;
    }

    var xMin = cache[0];
    var xMax = cache[1];
    var yMin = cache[2];
    var yMax = cache[3];
    var pruneEmpty = ref.pruneEmptyCell;

    for (y in yMin...yMax) {
      for (x in xMin...xMax) {
        var cellData = getCell(ref, x, y);

        if (cellData != null) {
          cellData.remove(key);
        }

        if (
          pruneEmpty &&
          Lambda.count(cellData) == 0
        ) {
          ref.data[y].remove(x);
        }
      }

      if (
        pruneEmpty &&
        Lambda.count(ref.data[y]) == 0
      ) {
        ref.data.remove(y);
      }
    }

    ref.itemCache.remove(key);
  }

  public static function tests() {
    assert('[grid] cell should have item', (hasPassed) -> {
      var ref = Grid.create(1);
      var id = Utils.uid();

      Grid.setItemRect(ref, 2, 3, 1, 1, id);
      hasPassed(
        Grid.has(ref, id) &&
          Lambda.count(Grid.getItemsInRect(ref, 2, 3, 1, 1)) == 1
      );
    });

    assert('[grid] cell should remove item', (hasPassed) -> {
      var ref = Grid.create(1);
      var id = Utils.uid();

      Grid.setItemRect(ref, 2, 3, 1, 1, id);
      Grid.removeItem(ref, id);
      hasPassed(
        !Grid.has(ref, id) &&
          Lambda.count(Grid.getItemsInRect(ref, 2, 3, 1, 1)) == 0
      );
    });

    assert('[grid] move item', (hasPassed) -> {
      var ref = Grid.create(1);
      var id = Utils.uid();

      Grid.setItemRect(ref, 2, 3, 1, 1, id);
      Grid.setItemRect(ref, 2, 4, 1, 1, id);

      hasPassed(
        Lambda.count(Grid.getItemsInRect(ref, 2, 3, 1, 1)) == 0 &&
          Lambda.count(Grid.getItemsInRect(ref, 2, 4, 1, 1)) == 1
      );
    });

    assert('[grid] add item rect exact fit', (hasPassed) -> {
      var ref = Grid.create(1);
      var width = 1;
      var height = 3;

      Grid.setItemRect(ref, 0, 1, width, height, Utils.uid());
      hasPassed(
        Lambda.count(ref.data) == height &&
         Lambda.count(ref.data[0]) == width
      );
    });

    assert('[grid] add item rect partial overlap', (hasPassed) -> {
      var cellSize = 10;
      var ref = Grid.create(cellSize);
      var width = cellSize - 1;
      var height = cellSize - 1;

      Grid.setItemRect(
        ref,
        Math.round(width / 2) + 2,
        Math.round(height / 2) + 2,
        width,
        height,
        Utils.uid()
      );

      hasPassed(
        Lambda.count(ref.data) == Math.ceil(cellSize / height) &&
         Lambda.count(ref.data[0]) == Math.ceil(cellSize / width)
      );
    });

    assert('[grid] get items in rect', (hasPassed) -> {
      var cellSize = 1;
      var ref = Grid.create(cellSize);
      var width = 2;
      var height = 2;
      var index = 0;

      for (y in 0...(height)) {
        for (x in 0...(width)) {
          Grid.setItemRect(ref, x, y, 1, 1, Utils.uid());
          index += 1;
        }
      }

      var queryX = Math.round(width / 2);
      var queryY = Math.round(height / 2);

      hasPassed(
        Lambda.count(
          Grid.getItemsInRect(ref, queryX, queryY, width, height)
        ) == 4
      );
    });
  }
}
