class AutoTile {

  static function getInnerCornerValue(
      curValue, grid, x, y, hasTile, gridOffset) {

    final northCoord = y - gridOffset;
    final eastCoord = x + gridOffset;
    final southCoord = y + gridOffset;
    final westCoord = x - gridOffset;

    final hasNorthEast = hasTile(
        Grid.getCell(
          grid, eastCoord, northCoord)); 
    
    if (!hasNorthEast) {
      return 16;
    }

    final hasSouthEast = hasTile(
        Grid.getCell(
          grid, eastCoord, southCoord)); 
    
    if (!hasSouthEast) {
      return 17;
    }

    final hasSouthWest = hasTile(
        Grid.getCell(
          grid, westCoord, southCoord)); 

    if (!hasSouthWest) {
      return 18;
    }

    final hasNorthWest = hasTile(
        Grid.getCell(
          grid, westCoord, northCoord)); 

    if (!hasNorthWest) {
      return 19;
    }

    return curValue;
  }

  /*
     [auto-tiling algorithms](https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673)
   */
  public static function getValue(
      grid: Grid.GridRef, 
      x, y, 
      hasTile, 
      gridOffset = 16, 
      checkInnerCorner = false) {
    final northCoord = y - gridOffset;
    final go = gridOffset;
    final north = hasTile(
        Grid.getCell(grid, x, northCoord)) ? 1 : 0;

    final eastCoord = x + gridOffset;
    final east = hasTile(
        Grid.getCell(grid, eastCoord, y)) ? 1 : 0;

    final southCoord = y + gridOffset;
    final south = hasTile(
        Grid.getCell(grid, x, southCoord)) ? 1 : 0;

    final westCoord = x - gridOffset;
    final west = hasTile(
        Grid.getCell(grid, westCoord, y)) ? 1 : 0;

    final value = north + (4 * east) + (8 * south) + (2 * west);

    // checks to see if the inside tile should be a special corner
    if (value == 15 && checkInnerCorner) {
      return getInnerCornerValue(
          value, grid, x, y, hasTile, gridOffset);
    }

    return value;
  }
}
