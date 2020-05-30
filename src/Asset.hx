import SaveState;

class Asset {
  public static function loadMap(mapName, onLoad, onError) {
    #if debugMode
    trace('loading environment grid state');
    #end

    var mapFile = '${mapName}.map';

    SaveState.load(
      #if jsMode
        '${Config.devServer}/load-state/${mapFile}',
        true,
      #else
        mapFile,
        false,
      #end
      onLoad,
      onError
    );
  }
}