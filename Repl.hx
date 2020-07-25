/*
   A simple repl designed to be run on the server for quick experiments
 */

class Repl {
  static function main() {
    final uiScale = 4;
    final invGrid = Grid.create(16 * uiScale);
    final mx = 32 * uiScale;
    final my = 32 * uiScale;
    final rectPixelWidth = 22 * uiScale;
    final rectPixelHeight = 22 * uiScale;
    final slotSize = 16 * uiScale;
    final rectWidth = Math.ceil(rectPixelWidth / slotSize) * slotSize;
    final rectHeight = Math.ceil(rectPixelHeight / slotSize) * slotSize;

    final slotX = 20 * slotSize;
    final slotY = 4 * slotSize;
    // add mock items
    Grid.setItemRect(
        invGrid,
        slotX,
        slotY,
        rectWidth,
        rectHeight,
        'mock_item_1');


    final slotX = 23 * slotSize;
    final slotY = 5 * slotSize;
    // add mock items
    Grid.setItemRect(
        invGrid,
        slotX,
        slotY,
        rectWidth,
        rectHeight,
        'mock_item_2');


    final slotX = 20 * slotSize;
    final slotY = 7 * slotSize;
    // add mock items
    Grid.setItemRect(
        invGrid,
        slotX + slotSize / 2,
        slotY + slotSize / 2,
        slotSize,
        slotSize,
        'mock_item_3');

    Grid.removeItem(
        invGrid, 
        'item_can_place');

    Grid.removeItem(
        invGrid, 
        'item_cannot_place');

    final cx = Math.floor((mx - rectWidth / 2) / slotSize) * slotSize;
    final cy = Math.floor((my - rectHeight / 2) / slotSize) * slotSize;
    final canPlace = Lambda.count(
        Grid.getItemsInRect(
          invGrid,
          cx,
          cy,
          rectWidth,
          rectHeight)) == 0;

   trace({
     canPlace: canPlace
   }); 
  }
}
