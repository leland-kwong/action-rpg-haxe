package core;

// seconds
typedef Time = Float;

typedef TiledMapData = { 
  layers:Array<{ data:Array<Int>}>, 
  tilewidth:Int, 
  tileheight:Int, 
  width:Int, 
  height:Int 
};

typedef MapDataRef = {
  var data: TiledMapData;
  var layersByName: Map<String, Dynamic>;
}

typedef TiledObject = {
  final id: Int;
  final x: Int;
  final y: Int;
  final width: Int;
  final height: Int;
  final type: String;
}

