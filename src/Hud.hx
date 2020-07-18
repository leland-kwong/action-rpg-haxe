using core.Types;

typedef UiAction = String;
typedef InventoryRef = {
  inventorySlots: Grid.GridRef,
  abilitySlots: Grid.GridRef
};
typedef UiElementRef = {
  > TiledObject,
  ?onClick: UiAction,
};
typedef TiledUiProp = {
  name: String,
  type: String,
  value: String,
};

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

  public static function findLayer(
      layerRef: TiledLayer, 
      name): TiledLayer {

    return Lambda.find(
        layerRef.layers, 
        (layer: TiledLayer) -> layer.name == name);
  }
}

class UiStateManager {
  public static function send(action: {
    type: String
  }) {
    final uiState = Main.Global.uiState;

    switch(action) {
      case { type: 'INVENTORY_TOGGLE' }: {
        final s = uiState.inventory;

        s.opened = !s.opened;
      }
      default: {
        throw 'invalid ui action ${action.type}';
      }
    } 
  } 
}

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

  public static function render(time: Float) {
    final state = Main.Global.uiState.inventory;
    if (!state.opened) {
      return;
    }

    final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
    final inventoryLayerRef = TiledParser
      .findLayer(hudLayoutRef, 'inventory');
    final backgroundLayer = TiledParser
      .findLayer(inventoryLayerRef, 'background');
    final bgObjects = backgroundLayer.objects;

    for (ref in bgObjects) {
      final cx = ref.x + ref.width / 2;
      final cy = ref.y - ref.height / 2;
      Main.Global.uiSpriteBatch.emitSprite(
          cx * Hud.rScale,
          cy * Hud.rScale,
          ref.name, 
          null,
          (p) -> {
            p.batchElement.scale = Hud.rScale;
          });
    }
  }
}

class UiGrid {
  static var colGrid = Grid.create(1);
  static final iList: Array<h2d.Interactive> = [];

  public static function update(dt: Float) {
    final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
    final inventoryLayerRef = TiledParser
      .findLayer(hudLayoutRef, 'hud');
    final interactLayer = TiledParser
      .findLayer(inventoryLayerRef, 'interactable');
    final objects = interactLayer.objects;
    final isInteractInitialized = iList.length != 0;

    for (ref in objects) {
      final cx = (ref.x + ref.width / 2) * Hud.rScale;
      final cy = (ref.y - ref.height / 2) * Hud.rScale;
      final width = ref.width * Hud.rScale;
      final height = ref.height * Hud.rScale;

      if (Main.Global.uiState.hud.enabled 
          && !isInteractInitialized) {
        final iRef = new h2d.Interactive(
            width,
            height,
            Main.Global.uiRoot);
        iRef.x = ref.x * Hud.rScale;
        iRef.y = (ref.y - ref.height) * Hud.rScale;

        final props = Utils.withDefault(ref.properties, []);
        for (p in props) {
          switch(p: TiledUiProp) {
            case { name: 'onClick' }: {
              iRef.onClick = (e: hxd.Event) -> {
                trace('click');
                UiStateManager.send({
                  type: p.value
                });
              }
            }
            default: {}
          }
        }
        
        iList.push(iRef); 
      }

      Grid.setItemRect(
          colGrid,
          cx, 
          cy, 
          width,
          height,
          Std.string(ref.id));
    }
  }

  public static function render(time: Float) {
    final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
    final inventoryLayerRef = TiledParser
      .findLayer(hudLayoutRef, 'hud');
    final interactLayer = TiledParser
      .findLayer(inventoryLayerRef, 'interactable');
    final objects = interactLayer.objects;
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

    final uiLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
    final hudLayer = TiledParser
      .findLayer(uiLayoutRef, 'hud');
    final cockpitUnderlay = TiledParser
      .findLayer(hudLayer, 'cockpit_underlay')
      .objects[0];
    final healthBars = TiledParser
      .findLayer(hudLayer, 'health_bars')
      .objects;
    final energyBars = TiledParser
      .findLayer(hudLayer, 'energy_bars')
      .objects;
    final barsCallback = (p) -> {
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
