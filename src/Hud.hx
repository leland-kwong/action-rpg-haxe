using core.Types;

class TiledParser {
  static var cache: Map<
    hxd.res.Resource, TiledMapData> = 
    new Map();

  public static function loadFile(
      res: hxd.res.Resource): TiledMapData {

    final fromCache = cache.get(res);

    if (fromCache != null) {
      return fromCache;
    }

    final data = haxe.Json.parse(res.entry.getText());
    cache.set(res, data);

    return data;
  }
}

private typedef TiledLayer = Array<TiledObject>;

typedef InventoryRef = {
  inventorySlots: Grid.GridRef,
  abilitySlots: Grid.GridRef
};

class Inventory {
  public static function create(): InventoryRef {
    return {
      inventorySlots: Grid.create(16),
      abilitySlots: Grid.create(16),
    };
  }

  public static function inventoryInteract(
      ref: InventoryRef) {
  }

  public static function inventoryInsert() {}

  public static function abilityInteract(
      ref: InventoryRef) {
  }
}

typedef UiAction = String;

typedef UiElementRef = {
  > TiledObject,
  ?onClick: UiAction,
};

class UiGrid {
  static var colGrid = Grid.create(8);

  static function getInteractLayer() {
    final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
    final inventoryLayer = Lambda.find(
        hudLayoutRef.layers,
        (layer) -> layer.name == 'hud');
    final interactLayer = Lambda.find(
        inventoryLayer.layers,
        (layer) -> layer.name == 'interactable');

    return interactLayer;
  }

  public static function update(dt: Float) {
    final objects = getInteractLayer().objects;

    for (ref in objects) {
      final cx = ref.x + ref.width / 2;
      final cy = ref.y - ref.height / 2;

      Grid.setItemRect(
          colGrid,
          cx * Hud.rScale, 
          cy * Hud.rScale, 
          ref.width * Hud.rScale,
          ref.height * Hud.rScale,
          Std.string(ref.id));
    }
  }

  public static function render(time: Float) {
    final objects = getInteractLayer().objects;
    final hoveredId = Lambda.find(
        Grid.getItemsInRect(
          colGrid,
          Main.Global.uiRoot.mouseX,
          Main.Global.uiRoot.mouseY,
          1, 1),
        (_) -> true);

    for (ref in objects) {
      final cx = ref.x + ref.width / 2;
      final cy = ref.y - ref.height / 2;
      Main.Global.uiSpriteBatch.emitSprite(
          cx * Hud.rScale,
          cy * Hud.rScale,
          ref.name, 
          null,
          (p) -> {
            p.batchElement.scale = Hud.rScale;

            switch(ref.name) {
              case 'ui/hud_inventory_button': {
                if (hoveredId == Std.string(ref.id)) {
                  p.batchElement.r = 0.0;
                  p.batchElement.g = 0.9;
                  p.batchElement.b = 1;
                }
              }
              default: {}
            }
          });
    }
  }
}

class Hud {
  public static var rScale = 4;
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

  public static function update(dt: Float) {
    Main.Global.worldMouse.hoverState = 
      Main.HoverState.None;

    // show hovered ai info
    {
      final healthBarHeight = 40;
      tf.x = Main.Global.uiRoot.width / 2;
      tf.y = 10;
      aiHealthBar.x = tf.x - aiHealthBarWidth / 2;
      aiHealthBar.y = 10;

      final x = Main.Global.rootScene.mouseX;
      final y = Main.Global.rootScene.mouseY;
      final hoveredEntityId = Utils.withDefault(
          Lambda.find(
            Grid.getItemsInRect(
              Main.Global.dynamicWorldGrid,
              x, y, 5, 5),
            (entityId) -> {
              final entRef = Entity.getById(entityId);
              final p = new h2d.col.Point(x, y);
              final c = new h2d.col.Circle(entRef.x, entRef.y, entRef.radius);
              final distFromMouse = Utils.distance(
                  x, y, entRef.x, entRef.y);
              final isMatch = c.contains(p) &&
                entRef.type == 'ENEMY';

              return isMatch;
            }),
          Entity.NULL_ENTITY.id);
      Main.Global.hoveredEntity.id = 
        hoveredEntityId;
      if (!Entity.isNullId(hoveredEntityId)) {
        Main.Global.worldMouse.hoverState = 
          Main.HoverState.Enemy;
        final entRef = Entity.getById(
          hoveredEntityId);
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

    // set hovered loot id
    if (Entity.isNullId(
          Main.Global.hoveredEntity.id)) {
      final NO_LOOT_ID = 'NO_LOOT_HOVERED';
      Main.Global.hoveredEntity.id = NO_LOOT_ID;

      final mWorldX = Main.Global.rootScene.mouseX;
      final mWorldY = Main.Global.rootScene.mouseY;
      final hoveredLootIds = Grid.getItemsInRect(
          Main.Global.lootColGrid,
          mWorldX,
          mWorldY,
          1,
          1);
      Main.Global.hoveredEntity.id = Utils.withDefault(
          Lambda.find(
            hoveredLootIds,
            (_) -> true),
          Entity.NULL_ENTITY.id);

      if (Entity.isNullId(
            Main.Global.hoveredEntity.id)) {
        Main.Global.hoveredEntity.hoverStart = -1.0;
      } else if (Main.Global.hoveredEntity.hoverStart == -1.0) {
        Main.Global.hoveredEntity.hoverStart = Main.Global.time;
      }

      if (Entity.isNullId(
            Main.Global.hoveredEntity.id)) {
        Main.Global.worldMouse.hoverState = 
          Main.HoverState.LootHovered;
      }
    }
  }

  public static function render(time: Float) {
    var ps = Main.Global.playerStats;

    if (ps == null) {
      return;
    }

    // resolution scale
    var mapLayers: Array<Dynamic> = mapData.layers;
    var hudLayer = Lambda.find(
        mapLayers,
        (l: Dynamic) -> {
          return l.name == 'hud';
        });
    var cockpitUnderlay = Lambda
      .find(hudLayer.layers, (l: Dynamic) -> {
        return l.name == 'cockpit_underlay';
      }).objects[0]; 
    var healthBars: TiledLayer = Lambda
      .find(hudLayer.layers, (l: Dynamic) -> {
        return l.name == 'health_bars';
      }).objects; 
    var energyBars: TiledLayer = Lambda
      .find(hudLayer.layers, (l: Dynamic) -> {
        return l.name == 'energy_bars';
      }).objects; 
    var barsCallback = (p) -> {
      p.sortOrder = 1.0;
      p.batchElement.scaleX = rScale * 1.0;
      p.batchElement.scaleY = rScale * 1.0;
    }

    {
      Main.Global.uiSpriteBatch.emitSprite(
          (cockpitUnderlay.x + 
           cockpitUnderlay.width / 2) * rScale,
          (cockpitUnderlay.y - 
           cockpitUnderlay.height / 2) * rScale,
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
            (item.x + item.width / 2) * rScale,
            (item.y - item.height / 2) * rScale,
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
            (item.x + item.width / 2) * rScale,
            (item.y - item.height / 2) * rScale,
            'ui/cockpit_resource_bar_energy',
            null,
            barsCallback);
      }
    }
  }
}
