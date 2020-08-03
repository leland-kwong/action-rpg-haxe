class AutoTile {
  /*
     [auto-tiling algorithms](https://gamedevelopment.tutsplus.com/tutorials/how-to-use-tile-bitmasking-to-auto-tile-your-level-layouts--cms-25673)
   */
  public static function getValue(
      grid: Grid.GridRef, x, y, hasTile, gridOffset = 16) {
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

    return north + (4 * east) + (8 * south) + (2 * west);
  }
}
