import Grid;
import SaveState;

class Tests {
  public static function run() {
    Grid.tests();
    SaveState.tests();
    core.Anim.test();
  }
}