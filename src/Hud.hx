using core.Types;

class TiledParser {
  public static function loadFile(
      res: hxd.res.Resource): TiledMapData {

    return haxe.Json.parse(res.entry.getText());
  }
}

private typedef TiledLayer = Array<TiledObject>;

class Hud {
  static var mapData: TiledMapData;

  public static function start() {
    mapData = TiledParser.loadFile(hxd.Res.ui_hud_layout_json);
  }

  public static function update(dt: Float) {
    var mapLayers: Array<Dynamic> = mapData.layers;
    var cockpitUnderlay = Lambda
      .find(mapLayers, (l: Dynamic) -> {
        return l.name == 'cockpit_underlay';
      }).objects[0]; 
    var healthBars: TiledLayer = Lambda
      .find(mapLayers, (l: Dynamic) -> {
        return l.name == 'health_bars';
      }).objects; 
    var energyBars: TiledLayer = Lambda
      .find(mapLayers, (l: Dynamic) -> {
        return l.name == 'energy_bars';
      }).objects; 
    var ps = Main.Global.playerStats;
    var barsCallback = (p, _) -> {
      p.sortOrder = 1;
      return 1;
    }

    Main.Global.uiSpriteBatch.emitSprite(
        cockpitUnderlay.x,
        cockpitUnderlay.y,
        cockpitUnderlay.x,
        cockpitUnderlay.y,
        0,
        'ui/cockpit_underlay',
        0.001, 
        (p, _) -> {
          p.sortOrder = 0;
          return 1;
        });

    {
      var healthRemaining = ps.currentHealth / ps.maxHealth;
      var numSegments = Math.ceil(healthRemaining * healthBars.length);
      var indexAdjust = healthBars.length - numSegments;

      for (i in 0...numSegments) {
        var item = healthBars[i + indexAdjust];

        Main.Global.uiSpriteBatch.emitSprite(
            item.x,
            item.y,
            item.x,
            item.y,
            0,
            'ui/cockpit_resource_bar_health',
            0.001,
            barsCallback);
      }
    }

    {
      var energyRemaining = ps.currentEnergy / ps.maxEnergy;
      var numSegments = Math.ceil(energyRemaining * energyBars.length);

      for (i in 0...numSegments) {
        var item = energyBars[i];

        Main.Global.uiSpriteBatch.emitSprite(
            item.x,
            item.y,
            item.x,
            item.y,
            0,
            'ui/cockpit_resource_bar_energy',
            0.001,
            barsCallback);
      }
    }
  }
}
