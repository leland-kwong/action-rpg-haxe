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
  var id: Int;
  var x: Int;
  var y: Int;
  var width: Int;
  var height: Int;
}

