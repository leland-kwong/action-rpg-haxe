import Grid;
import SaveState;

class Tests {
  public static function run() {

#if !production
    Grid.tests();
    SaveState.tests();
    Gui.tests();
    HaxeUtils.tests();
    //core.Anim.test();
#end

  }
}
