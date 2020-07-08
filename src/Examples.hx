using core.Types;

private typedef TiledLayer = Array<TiledObject>;

class Examples {
  public static function start() {
    var mapData:TiledMapData = haxe.Json.parse(
        hxd.Res.ui_hud_layout_json.entry.getText());
    var mapLayers: Array<Dynamic> = mapData.layers;
    var cockpitUnderlay = Lambda.find(mapLayers, (l: Dynamic) -> {
      return l.name == 'cockpit_underlay';
    }).objects[0]; 
    var healthBars: TiledLayer = Lambda.find(mapLayers, (l: Dynamic) -> {
      return l.name == 'health_bars';
    }).objects; 
    var energyBars: TiledLayer = Lambda.find(mapLayers, (l: Dynamic) -> {
      return l.name == 'energy_bars';
    }).objects; 

    Main.Global.uiSpriteBatch.emitSprite(
        cockpitUnderlay.x * Main.Global.pixelScale,
        cockpitUnderlay.y * Main.Global.pixelScale,
        cockpitUnderlay.x * Main.Global.pixelScale,
        cockpitUnderlay.y * Main.Global.pixelScale,
        0,
        'ui/cockpit_underlay',
        1000, 
        (p, _) -> {
          p.sortOrder = 0;
          return Main.Global.pixelScale;
        });

    for (item in healthBars) {
      Main.Global.uiSpriteBatch.emitSprite(
          item.x * Main.Global.pixelScale,
          item.y * Main.Global.pixelScale,
          item.x * Main.Global.pixelScale,
          item.y * Main.Global.pixelScale,
          0,
          'ui/cockpit_resource_bar_health',
          1000,
          (p, _) -> {
            p.sortOrder = 1;
            return Main.Global.pixelScale;
          });
    }

    for (item in energyBars) {
      Main.Global.uiSpriteBatch.emitSprite(
          item.x * Main.Global.pixelScale,
          item.y * Main.Global.pixelScale,
          item.x * Main.Global.pixelScale,
          item.y * Main.Global.pixelScale,
          0,
          'ui/cockpit_resource_bar_energy',
          1000,
          (p, _) -> {
            p.sortOrder = 1;
            return Main.Global.pixelScale;
          });
    }
  }

  public static function update(dt: Float) {

  }
}
