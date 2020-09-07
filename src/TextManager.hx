class TextManager {
  static var instances: Array<h2d.Text> = [];

  public static function get() {
    final inst = new h2d.Text(Fonts.primary());
    instances.push(inst);

    return inst;
  } 

  public static function resetAll() {
#if debugMode
    Main.Global.logData.textManager = {
      numInstances: instances.length
    };
#end

    for (inst in instances) {
      inst.remove();
    }
    instances = [];
  } 
}
