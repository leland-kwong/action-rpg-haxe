class Debug {
  public static function traversableAreas(
      traversableGrid: Grid.GridRef,
      spriteSheetTile: h2d.Tile,
      spriteSheetData,
      tg: h2d.TileGroup) {
    for (itemId => bounds in traversableGrid.itemCache) {
      final spriteKey = 'ui/square_white';
      final spriteData = Reflect.field(
          spriteSheetData,
          spriteKey);
      final tile = spriteSheetTile.sub(
          spriteData.frame.x,
          spriteData.frame.y,
          spriteData.frame.w,
          spriteData.frame.h);
      final cellSize = traversableGrid.cellSize;
      final w = (bounds[1] - bounds[0]) * cellSize;
      final h = (bounds[3] - bounds[2]) * cellSize;
      tile.scaleToSize(w, h);
      if (Main.Global.logData.boundsInfo == null) {
        Main.Global.logData.boundsInfo = true;
        trace('traversable rect', w, h);
      }
      tg.addColor(
          bounds[0] * cellSize,
          bounds[2] * cellSize,
          0.8,
          0.2,
          0.3,
          0.3,
          tile);
    }
  }
}
