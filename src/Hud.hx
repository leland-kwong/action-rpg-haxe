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
  static var tf: h2d.Text;
  static var aiHealthBar: h2d.Graphics;
  static final aiHealthBarWidth = 200;
  static var hoveredEntityId: Entity.EntityId;

  public static function init() {
    aiHealthBar = new h2d.Graphics(
        Main.Global.uiRoot);
    final font = Fonts.primary.get().clone();
    font.resizeTo(24);
    tf = new h2d.Text(
        font, 
        Main.Global.uiRoot);
    tf.textAlign = Center;
    tf.textColor = Game.Colors.pureWhite;

    mapData = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
  }

  public static function render(time: Float) {
    // show hovered ai info
    {
      final healthBarHeight = 40;
      tf.x = Main.Global.uiRoot.width / 2;
      tf.y = 10;
      aiHealthBar.x = tf.x - aiHealthBarWidth / 2;
      aiHealthBar.y = 10;

      final x = Main.Global.rootScene.mouseX;
      final y = Main.Global.rootScene.mouseY;
      final hoveredEntityId = Lambda.find(
          Grid.getItemsInRect(
            Main.Global.dynamicWorldGrid,
            x, y, 5, 5),
          (entityId) -> {
            final entRef = Entity.ALL_BY_ID[entityId];
            final p = new h2d.col.Point(x, y);
            final c = new h2d.col.Circle(entRef.x, entRef.y, entRef.radius);
            final distFromMouse = Utils.distance(
                x, y, entRef.x, entRef.y);
            final isMatch = c.contains(p) &&
              entRef.type == 'ENEMY';

            return isMatch;
          });
      if (hoveredEntityId != null) {
        final entRef = Entity.ALL_BY_ID[
          hoveredEntityId];
        tf.text = entRef.type;
        final healthPctRemain = entRef.health / 
          entRef.stats.maxHealth;
        aiHealthBar.clear();
        aiHealthBar.lineStyle(4, Game.Colors.black);
        aiHealthBar.beginFill(Game.Colors.black);
        aiHealthBar.drawRect(
            0, 0, 
            aiHealthBarWidth, 
            healthBarHeight);
        aiHealthBar.beginFill(Game.Colors.red);
        aiHealthBar.drawRect(
            0, 0, 
            healthPctRemain * aiHealthBarWidth, 
            healthBarHeight);
      } else {
        tf.text = '';
        aiHealthBar.clear();
      }
    }

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
      p.sortOrder = 1.0;
      p.batchElement.scaleX = rScale * 1.0;
      p.batchElement.scaleY = rScale * 1.0;
    }

    {
      Main.Global.uiSpriteBatch.emitSprite(
          cockpitUnderlay.x * rScale,
          cockpitUnderlay.y * rScale,
          'ui/cockpit_underlay',
          null,
          (p) -> {
            p.sortOrder = 0.0;
            p.batchElement.scaleX = rScale * 1.0;
            p.batchElement.scaleY = rScale * 1.0;
          });
    }

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
            'ui/cockpit_resource_bar_health',
            null, 
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
            'ui/cockpit_resource_bar_energy',
            null,
            barsCallback);
      }
    }
  }
}
