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
    mapData = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
  }

  public static function update(dt: Float) {
    var ps = Main.Global.playerStats;

    if (ps == null) {
      return;
    }

    // resolution scale
    var rScale = 4;
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
    var barsCallback = (p) -> {
      p.sortOrder = 1;
      p.batchElement.scaleX = rScale * 1.0;
      p.batchElement.scaleY = rScale * 1.0;
      return rScale;
    }

    Main.Global.uiSpriteBatch.emitSprite(
        cockpitUnderlay.x * rScale,
        cockpitUnderlay.y * rScale,
        cockpitUnderlay.x * rScale,
        cockpitUnderlay.y * rScale,
        'ui/cockpit_underlay',
        (p) -> {
          p.sortOrder = 0;
          p.batchElement.scaleX = rScale * 1.0;
          p.batchElement.scaleY = rScale * 1.0;
          return rScale;
        });

    {
      var healthRemaining = 
        ps.currentHealth / ps.maxHealth;
      var numSegments = Math.ceil(
          healthRemaining * healthBars.length);
      var indexAdjust = 
        healthBars.length - numSegments;

      for (i in 0...numSegments) {
        var item = healthBars[i + indexAdjust];

        Main.Global.uiSpriteBatch.emitSprite(
            item.x * rScale,
            item.y * rScale,
            item.x * rScale,
            item.y * rScale,
            'ui/cockpit_resource_bar_health',
            barsCallback);
      }
    }

    {
      var energyRemaining = 
        ps.currentEnergy / ps.maxEnergy;
      var numSegments = Math.ceil(
          energyRemaining * energyBars.length);

      for (i in 0...numSegments) {
        var item = energyBars[i];

        Main.Global.uiSpriteBatch.emitSprite(
            item.x * rScale,
            item.y * rScale,
            item.x * rScale,
            item.y * rScale,
            'ui/cockpit_resource_bar_energy',
            barsCallback);
      }
    }
  }
}
