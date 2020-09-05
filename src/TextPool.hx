class TextPool {
  static var pool: Array<h2d.Text> = [];
  static final instances: Array<h2d.Text> = [];

  public static function get() {
    final fromPool = pool.pop();

    if (fromPool != null) {
      return fromPool;
    }

    final inst = new h2d.Text(Fonts.primary());
    instances.push(inst);
    return inst;
  } 

  public static function resetAll() {
    pool = instances.copy();

    for (inst in instances) {
      inst.text = '';
      inst.textAlign = Left;
      inst.font = Fonts.primary();
      inst.textColor = 0xffffff;
    }

#if debugMode
    Main.Global.logData.textPool = {
      poolSize: pool.length,
      numInstances: instances.length
    };
#end
  } 
}
