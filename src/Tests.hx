import Grid;
import SaveState;

class Tests {
  public static function run() {

#if !production
    Grid.tests();
    SaveState.tests();
    Gui.tests();
    HaxeUtils.tests();
    Session.unitTests();
    //core.Anim.test();
#end

  }
}
