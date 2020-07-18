package core;

// seconds
typedef Time = Float;

typedef TiledObject = {
  final id: Int;
  final x: Int;
  final y: Int;
  final width: Int;
  final height: Int;
  final type: String;
  final name: String;
}

typedef TiledLayer = {
  final name: String;
  final ?objects: Array<TiledObject>;
  final ?layers: Array<TiledLayer>;
};

typedef TiledMapData = { 
  > TiledLayer,
  tilewidth:Int, 
  tileheight:Int, 
  width:Int, 
  height:Int,
};

typedef MapDataRef = {
  var data: TiledMapData;
  var layersByName: Map<String, Dynamic>;
}

