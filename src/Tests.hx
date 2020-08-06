import Grid;
import SaveState;

class Tests {
  public static function run() {
    Grid.tests();
    SaveState.tests();
    Gui.tests();
    //core.Anim.test();
  }
}
