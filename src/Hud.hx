using core.Types;
import Entity;
import Grid;
import Loot;

typedef UiAction = {
  type: String,
  ?data: Dynamic
};
typedef InventoryRef = {
  inventorySlots: Grid.GridRef,
  abilitySlots: Grid.GridRef
};
typedef TiledUiProp = {
  name: String,
  type: String,
  value: Dynamic,
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
  static var listeners = [];

  public static function send(action: UiAction) {
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
  static var ready = false;
  static var interactGrid = Grid.create(16 * Hud.rScale);
  static var debugGraphic: h2d.Graphics;

  public static var state: {
    inventorySlotsGrid: GridRef,
    abilitySlotsGrid: GridRef,
    lootInstancesById: Map<EntityId, LootInstance>
  } = {
    // inventory grid resolution is a single slot
    inventorySlotsGrid: Grid.create(1), 
    abilitySlotsGrid: Grid.create(16 * Hud.rScale),
    lootInstancesById: new Map()
  };

  public static function inventorySlotInteract(
      ref: InventoryRef) {
  }

  // puts an item into the first available slot
  // dimensions are based on the native 
  // pixel art's resolution (480 x 270)
  public static function inventorySlotAddItem(
      itemId, 
      pixelWidth, 
      pixelHeight, 
      itemInstance: Loot.LootInstance): Bool {

    final invGrid = state.inventorySlotsGrid;
    final cellSize = invGrid.cellSize;
    final slotDefinition = {
      final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json); 
      final inventoryLayerRef = TiledParser
        .findLayer(hudLayoutRef, 'inventory');
      final interactRef = TiledParser
        .findLayer(
            inventoryLayerRef, 'interactable');
      Lambda.find(
          interactRef.objects,
          (o) -> o.name == 'inventory_slots');
    }
    final slotSize: Int = Lambda.find(
        slotDefinition.properties, 
        (p: TiledUiProp) -> p.name == 'slotSize').value;
    // convert item dimensions to slot units 
    final sw = Math.ceil(pixelWidth / slotSize);
    final sh = Math.ceil(pixelHeight / slotSize);
    final maxCol = Std.int(slotDefinition.width / slotSize);
    final maxRow = Std.int(slotDefinition.height / slotSize);
    final maxY = maxRow - 1;
    final maxX = maxCol - 1;

    for (y in 0...maxRow) {
      for (x in 0...maxCol) {
        final cx = x + Math.floor(sw / 2);
        final cy = y + Math.floor(sh / 2);
        final filledSlots = Grid.getItemsInRect(
            invGrid, cx, cy, sw, sh);
        final canFit = Lambda.count(
            filledSlots) == 0
          && cx - Math.floor(sw / 2) >= 0
          && cx + Math.floor(sw / 2) <= maxX + 1
          && cy + Math.floor(sh / 2) <= maxY + 1
          && cy - Math.floor(sh / 2) >= 0;

        // add success
        if (canFit) {
          Grid.setItemRect(
              invGrid, cx, cy, sw, sh, itemId);
          state.lootInstancesById
            .set(itemId, itemInstance);
          return true;
        }
      }
    }
 
    return false;
  }

  public static function abilityInteract(
      ref: InventoryRef) {
  }

  public static function update(dt: Float) {
    if (!ready) {

      ready = true;

      trace('setup inventory interact grid');

      final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json); 
      final inventoryLayerRef = TiledParser
        .findLayer(hudLayoutRef, 'inventory');
      final interactLayer = TiledParser
        .findLayer(inventoryLayerRef, 'interactable');
      final interactObjects = interactLayer.objects;

      for (o in interactObjects) {
        Grid.setItemRect(
            interactGrid,
            (o.x + (o.width / 2)) * Hud.rScale,
            (o.y + (o.height / 2)) * Hud.rScale,
            o.width * Hud.rScale,
            o.height * Hud.rScale,
            'iInteract_${o.id}');
      }
    }

    // handle loot hover/pickup interaction
    final entityRef = Entity.getById(Main.Global.hoveredEntity.id);
    if (entityRef == Entity.NULL_ENTITY || 
        entityRef.type == 'LOOT') {
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

      final hoveredId = Main.Global.hoveredEntity.id;
      final lootRef = Entity.getById(hoveredId);
      final playerRef = Entity.getById('PLAYER');
      final pickupRadius = 40;
      final isPickupMode = lootRef.type == 'LOOT' &&
        (Main.Global.worldMouse.buttonDownStartedAt >
         Main.Global.hoveredEntity.hoverStart);
      final distFromPlayer = Utils.distance(
          playerRef.x, playerRef.y, lootRef.x, lootRef.y);
      final canPickupItem = isPickupMode && 
        distFromPlayer <= pickupRadius;
      if (canPickupItem) {
        if (Main.Global.worldMouse.buttonDown == 0) {
          Main.Global.worldMouse.hoverState = 
            Main.HoverState.LootHoveredCanPickup;
        }

        final pickupItemButtonClicked = 
          Main.Global.worldMouse.clicked;
        if (pickupItemButtonClicked) {
          final size = lootRef.radius * 2;
          final addSuccess = Inventory.inventorySlotAddItem(
              lootRef.id, 
              size, 
              size, 
              Entity.getComponent(lootRef, 'lootInstance'));

          if (addSuccess) {
            final animDuration = 0.2;
            final startTime = Main.Global.time;
            final flyToPlayerThenDestroy = (dt: Float) -> {
              final angleToPlayer = Math.atan2(
                  playerRef.y - lootRef.y,
                  playerRef.x - lootRef.x);
              final dx = Math.cos(angleToPlayer);
              final dy = Math.sin(angleToPlayer);
              final progress = (Main.Global.time - startTime) 
                / animDuration;
              final speed = 350;
              lootRef.x += dx * speed * dt;
              lootRef.y += dy * speed * dt;

              final d = Utils.distance(
                  lootRef.x, lootRef.y, playerRef.x, playerRef.y);
              final done = d <= 5;
              if (done) {
                Entity.destroy(lootRef.id);
                return false;
              }

              return true;
            };
            Main.Global.updateHooks.push(
                flyToPlayerThenDestroy);
          }

          // visual feedback to show item pickup failure
          if (!addSuccess) {
            final lootRefOriginalX = lootRef.x;
            final lootRefOriginalY = lootRef.y;
            final dx = Utils.irnd(-5, 5, true);
            final startTime = Main.Global.time;
            final duration = 0.4;
            Main.Global.updateHooks.push((dt: Float) -> {
              final progress = (Main.Global.time - startTime) / duration;
              final z = Math.sin(Math.PI * progress) * 15;
              lootRef.x = lootRefOriginalX + progress * dx;
              lootRef.y = lootRefOriginalY - z;

              return progress < 1;
            });
          }
        }
      }
    }
  }

  public static function render(time: Float) {
    final globalState = Main.Global.uiState.inventory;

    debugGraphic = debugGraphic == null 
      ? new h2d.Graphics(Main.Global.uiRoot)
      : debugGraphic;
    debugGraphic.clear();

    if (!globalState.opened) {
      return;
    }

    // render inventory items
    {
      final slotSize = 16 * Hud.rScale;
      final cellRenderEffect = (p) -> {
        final b: h2d.SpriteBatch.BatchElement 
          = p.batchElement;
        p.sortOrder = 2.0;
        b.scale = slotSize - 4;
        b.alpha = 0.3;
        b.r = 0.5;
      };

      for (lootId => bounds in 
          state.inventorySlotsGrid.itemCache) {
        final x = bounds[0];
        final y = bounds[2];
        final width = bounds[1] - x;
        final height = bounds[3] - y;
        final lootInstance = state.lootInstancesById.get(lootId);
        final lootDef = Loot.getDef(
            lootInstance.type);

        Main.Global.uiSpriteBatch.emitSprite(
            (x * slotSize) + (width / 2 * slotSize) + 272 * Hud.rScale,
            (y * slotSize) + (height / 2 * slotSize) + 32 * Hud.rScale,
            lootDef.spriteKey,
            (p) -> {
              p.batchElement.scale = Hud.rScale;
            });
      }
    }
    
    // debug render interactable slots
    // {
    //   final cellSize = interactGrid.cellSize;
    //   for (y => col in interactGrid.data) {
    //     for (x => cell in col) {
    //       Main.Global.logData.interactPosition = {
    //         x: x * cellSize,
    //         y: y * cellSize
    //       };
    //       final cellRenderEffect = (p) -> {
    //         final b: h2d.SpriteBatch.BatchElement 
    //           = p.batchElement;
    //         p.sortOrder = 1.0;
    //         b.scale = cellSize - 4;
    //         b.alpha = 0.2;
    //       };
    //       Main.Global.uiSpriteBatch.emitSprite(
    //           (x * cellSize),
    //           (y * cellSize),
    //           'ui/square_white',
    //           null,
    //           cellRenderEffect);   
    //     }
    //   }
    // }

    final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
    final inventoryLayerRef = TiledParser
      .findLayer(hudLayoutRef, 'inventory');
    final backgroundLayer = TiledParser
      .findLayer(inventoryLayerRef, 'background');
    final bgObjects = backgroundLayer.objects;

    for (ref in bgObjects) {
      final cx = ref.x;
      final cy = ref.y;
      Main.Global.uiSpriteBatch.emitSprite(
          cx * Hud.rScale,
          cy * Hud.rScale,
          ref.name, 
          null,
          (p) -> {
            p.sortOrder = 0;
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
                final isHovered = hoveredId == 
                  Std.string(ref.id);
                if (isHovered) {
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

class Tooltip {
  static var tooltipTextRef: h2d.Text;

  public static function update(dt: Float) {
    final initialized = tooltipTextRef != null;

    if (!initialized) {
      final font = Main.Global.fonts.primary.clone();
      tooltipTextRef = new h2d.Text(
          font);
    }

    final entityRef = Entity.getById(
        Main.Global.hoveredEntity.id);

    if (entityRef.type != 'LOOT') {
      tooltipTextRef.remove();

      return;
    }

    Main.Global.uiRoot.addChild(tooltipTextRef);
    tooltipTextRef.textAlign = Center;
    final lootType = Entity.getComponent(
        entityRef, 
        'lootInstance').type;
    final displayName = Loot.getDef(lootType).name;
    tooltipTextRef.text = displayName;
    tooltipTextRef.textColor = 0xffffff;
  }

  public static function render(time: Float) {
    final entityRef = Entity.getById(
        Main.Global.hoveredEntity.id);

    if (entityRef.type != 'LOOT') {
      return;
    }

    final lootRef = entityRef;
    final ttWorldPos = Camera.toScreenPos(
        Main.Global.mainCamera, 
        lootRef.x, lootRef.y);
    tooltipTextRef.x = ttWorldPos[0] * Hud.rScale;
    tooltipTextRef.y = (ttWorldPos[1] - 25) * Hud.rScale;

    // tooltip background
    final ttPaddingH = 5;
    final ttPaddingV = 2;
    Main.Global.sb.emitSprite(
        lootRef.x - (ttPaddingH / 2) - 
        tooltipTextRef.textWidth / 2 / Hud.rScale,
        lootRef.y - (ttPaddingV / 2) - 25,
        'ui/square_white',
        null,
        (p) -> {
          p.batchElement.scaleX = ttPaddingH + 
            tooltipTextRef.textWidth / Hud.rScale;
          p.batchElement.scaleY = ttPaddingV + 
            tooltipTextRef.textHeight / Hud.rScale;
          p.batchElement.r = 0;
          p.batchElement.g = 0;
          p.batchElement.b = 0;
          p.batchElement.a = 0.9;
        });
  }
}

class InventoryDragAndDropPrototype {
  static var debugGraphic: h2d.Graphics;

  static final NULL_PICKUP_ID = 'NO_ITEM_PICKED_UP';
  static final state = {
    initialized: false,
    invGrid: Grid.create(16 * Hud.rScale),
    debugGrid: Grid.create(16 * Hud.rScale),
    pickedUpItemId: NULL_PICKUP_ID,
    itemsById: [
      NULL_PICKUP_ID => {
        slotWidth: 16 * Hud.rScale,
        slotHeight: 16 * Hud.rScale
      }
    ]
  };

  public static function update(dt) {
    Main.Global.worldMouse.hoverState = 
      Main.HoverState.Ui;

    final slotSize = 16 * Hud.rScale;

    if (!state.initialized) {
      state.initialized = true;

      debugGraphic = new h2d.Graphics(Main.Global.uiRoot);

      final addItemToInv = (
          slotX, slotY, slotWidth, slotHeight, itemId) -> {
        Grid.setItemRect(
            state.invGrid,
            slotX + (slotWidth / 2),
            slotY + (slotHeight / 2),
            slotWidth,
            slotHeight,
            itemId);
        state.itemsById.set(
            itemId, 
            { 
              slotWidth: slotWidth, 
              slotHeight: slotHeight
            });
      }

      {
        final slotX = 20 * slotSize;
        final slotY = 4 * slotSize;
        final w = 2 * slotSize;
        final h = 2 * slotSize;
        // add mock items
        addItemToInv(
            slotX,
            slotY,
            w,
            h,
            Utils.uid());
      }

      {
        final slotX = 23 * slotSize;
        final slotY = 5 * slotSize;
        final w = 2 * slotSize;
        final h = 3 * slotSize;
        // add mock items
        addItemToInv(
            slotX,
            slotY,
            w,
            h,
            Utils.uid());
      }

      {
        final slotX = 21 * slotSize;
        final slotY = 8 * slotSize;
        final w = 1 * slotSize;
        final h = 1 * slotSize;
        // add mock items
        addItemToInv(
            slotX,
            slotY,
            w,
            h,
            Utils.uid());
      }

      {
        final slotX = 22 * slotSize;
        final slotY = 8 * slotSize;
        final w = 1 * slotSize;
        final h = 1 * slotSize;
        // add mock items
        addItemToInv(
            slotX,
            slotY,
            w,
            h,
            Utils.uid());
      }

      {
        final slotX = 22 * slotSize;
        final slotY = 10 * slotSize;
        final w = 1 * slotSize;
        final h = 1 * slotSize;
        // add mock items
        addItemToInv(
            slotX,
            slotY,
            w,
            h,
            Utils.uid());
      }

      {
        final slotX = 26 * slotSize;
        final slotY = 7 * slotSize;
        final w = 1 * slotSize;
        final h = 3 * slotSize;
        // add mock items
        addItemToInv(
            slotX,
            slotY,
            w, h,
            Utils.uid());
      }
    }

    // handle mouse interaction
    {
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
      final pickedUpItem = state.itemsById.get(
          state.pickedUpItemId);
      final w = pickedUpItem.slotWidth;
      final h = pickedUpItem.slotHeight;
      /*
         The goal is to translate the mouse position such that it represents
         the center of the rectangle that fits the slots the best. The algorithm
         to do this is:

         1. Translate the mouse so that its origin is at the upper-left
         corner of the rectangle. 
         2. Round new origin to the nearest slot unit.
         3. Translate coordinates to center of rectangle based on new origin.
       */
      final halfWidth = (w / 2);
      final halfHeight = (h / 2);
      final mouseSlotX = Math.round((mx - halfWidth) / slotSize) * slotSize;
      final mouseSlotY = Math.round((my - halfHeight) / slotSize) * slotSize;
      final cx = mouseSlotX + halfWidth;
      final cy = mouseSlotY + halfHeight;

      Grid.removeItem(
          state.debugGrid, 
          'item_can_place');

      Grid.removeItem(
          state.debugGrid, 
          'item_cannot_place');

      final canPlace = Lambda.count(
          Grid.getItemsInRect(
            state.invGrid,
            cx,
            cy,
            w,
            h)) <= 1;

      if (Main.Global.worldMouse.clicked) {
        final hasPickedUp = state.pickedUpItemId != 
          NULL_PICKUP_ID;

        final currentlyPickedUpItem = state.pickedUpItemId;

        if (canPlace) {
          trace('pickup item', state.pickedUpItemId);

          final getFirstKey = (keys: Iterator<GridKey>) -> {
            for (k in keys) {
              return k;
            }
            return NULL_PICKUP_ID;
          }

          final itemIdAtPosition = getFirstKey(
              Grid.getItemsInRect(
                state.invGrid,
                cx,
                cy,
                w, h).keys());

          Grid.removeItem(
              state.invGrid,
              itemIdAtPosition);

          state.pickedUpItemId = itemIdAtPosition;
        }

        if (hasPickedUp && canPlace) {
          trace('drop item');

          // state.pickedUpItemId   
          Grid.setItemRect(
              state.invGrid,
              cx,
              cy,
              w, h,
              currentlyPickedUpItem);
        }
      }

      Grid.setItemRect(
          state.debugGrid,
          cx,
          cy,
          w,
          h,
          canPlace ? 
          'item_can_place' : 
          'item_cannot_place');
    }
  }
  public static function render(time) {
    final cellSize = state.invGrid.cellSize;

    // render inventory items
    debugGraphic.clear();
    debugGraphic.beginFill(0xffffff, 0.4);
    debugGraphic.lineStyle(2, 0xffffff);
    for (itemId => bounds in state.invGrid.itemCache) {
      final width = bounds[1] - bounds[0];
      final height = bounds[3] - bounds[2];
      final cx = Math.ceil(bounds[0] + width / 2);
      final cy = Math.ceil(bounds[2] + height / 2);
      
      debugGraphic.drawRect(
          bounds[0] * cellSize,
          bounds[2] * cellSize,
          width * cellSize,
          height * cellSize);
    } 

    // render pickup status
    for (itemId => bounds in state.debugGrid.itemCache) {
      final width = bounds[1] - bounds[0];
      final height = bounds[3] - bounds[2];

      if (itemId == 'item_can_place') {
        debugGraphic.beginFill(0x00c3ff, 0.4);
      }

      if (itemId == 'item_cannot_place') {
        debugGraphic.beginFill(0xd60000, 0.4);
      }

      debugGraphic.lineStyle(0);
      debugGraphic.drawRect(
          bounds[0] * cellSize,
          bounds[2] * cellSize,
          width * cellSize,
          height * cellSize);
    } 

    // render picked up item
    if (state.pickedUpItemId != NULL_PICKUP_ID) {
      final itemData = state.itemsById
        .get(state.pickedUpItemId);
      final w = itemData.slotWidth;
      final h = itemData.slotHeight;

      debugGraphic.beginFill(0xffffff, 0.8);
      debugGraphic.drawRect(
          Main.Global.uiRoot.mouseX - w / 2,
          Main.Global.uiRoot.mouseY - h / 2,
          w, h);
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
  static var tooltipTf: h2d.Text;

  public static function init() {
    aiHealthBar = new h2d.Graphics(
        Main.Global.uiRoot);
    final font = Main.Global.fonts.primary;
    tf = new h2d.Text(
        font, 
        Main.Global.uiRoot);
    tf.textAlign = Center;
    tf.textColor = Game.Colors.pureWhite;

    mapData = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
  }

  public static function update(dt: Float) {
    Tooltip.update(dt);
    InventoryDragAndDropPrototype.update(dt);

    Main.Global.worldMouse.hoverState = 
      Main.HoverState.None;

    // show hovered ai info
    {
      final healthBarHeight = 30;
      tf.x = Main.Global.uiRoot.width / 2;
      tf.y = 10;
      aiHealthBar.x = tf.x - aiHealthBarWidth / 2;
      aiHealthBar.y = 35;

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

  }

  public static function render(time: Float) {
    Tooltip.render(time);
    InventoryDragAndDropPrototype.render(time);

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
