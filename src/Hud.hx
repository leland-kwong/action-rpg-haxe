using core.Types;
import Entity;
import Grid;

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
private typedef EquippableSlotMeta = {
  equippedItemId: String,
  allowedCategory: Loot.LootDefCat,
  // slot dimensions and ui position
  x: Int,
  y: Int,
  width: Int,
  height: Int,
}

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

        if (!s.opened) {
          s.opened = true;
          final closeInventory = () -> {
            s.opened = false;
          };
          Stack.push(
              Main.Global.escapeStack, 
              'close inventory',
              closeInventory);
        } else {
          Stack.pop(Main.Global.escapeStack);
        } 
      }
      default: {
        throw 'invalid ui action ${action.type}';
      }
    } 
  } 
}

class Inventory {
  // Puts an item into the first available slot.
  //
  // Dimensions are based on the native 
  // pixel art's resolution (480 x 270)
  public static function inventorySlotAddItem(
      itemInstance: Loot.LootInstance): Bool {

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
    final lootDef = Loot.getDef(itemInstance.type);
    final spriteData = SpriteBatchSystem.getSpriteData(
        Main.Global.uiSpriteBatch,
        lootDef.spriteKey);
    final pixelWidth = spriteData.sourceSize.w;
    final pixelHeight = spriteData.sourceSize.h;
    final sw = Math.ceil(pixelWidth / slotSize);
    final sh = Math.ceil(pixelHeight / slotSize);
    final maxCol = Std.int(slotDefinition.width / slotSize);
    final maxRow = Std.int(slotDefinition.height / slotSize);
    final maxY = maxRow - 1;
    final maxX = maxCol - 1;
    final cellSize = InventoryDragAndDropPrototype
      .state.invGrid.cellSize;

    // look for nearest empty cell and put item in if available
    for (y in 0...maxRow) {
      for (x in 0...maxCol) {
        final cx = x + Math.floor(sw / 2);
        final cy = y + Math.floor(sh / 2);
        final filledSlots = Grid.getItemsInRect(
            InventoryDragAndDropPrototype.state.invGrid, 
            x * cellSize + (sw / 2) * cellSize, 
            y * cellSize + (sh / 2) * cellSize, 
            sw * cellSize,
            sh * cellSize);
        final canFit = Lambda.count(
            filledSlots) == 0
          && cx - Math.floor(sw / 2) >= 0
          && cx + Math.floor(sw / 2) <= maxX + 1
          && cy + Math.floor(sh / 2) <= maxY + 1
          && cy - Math.floor(sh / 2) >= 0;

        // add success
        if (canFit) {
          InventoryDragAndDropPrototype.addItemToInventory(
              x * cellSize + (sw / 2) * cellSize, 
              y * cellSize + (sh / 2) * cellSize, 
              sw * cellSize,
              sh * cellSize,
              itemInstance);
          return true;
        }
      }
    }
 
    return false;
  }

  public static function update(dt: Float) {
    // handle game world loot hover/pickup interaction
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

      if (entityRef.type == 'LOOT') {
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
      final playerCanPickupItem = isPickupMode && 
        distFromPlayer <= pickupRadius;
      if (playerCanPickupItem) {
        if (Main.Global.worldMouse.buttonDown == 0) {
          Main.Global.worldMouse.hoverState = 
            Main.HoverState.LootHoveredCanPickup;
        }

        final pickupItemButtonClicked = 
          Main.Global.worldMouse.clicked;
        if (pickupItemButtonClicked) {
          final size = lootRef.radius * 2;
          final addSuccess = Inventory.inventorySlotAddItem(
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

          // visual feedback to show item pickup failure (bounce item up then down)
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

    if (!globalState.opened) {
      return;
    }

    final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json);
    final inventoryLayerRef = TiledParser
      .findLayer(hudLayoutRef, 'inventory');
    final backgroundLayer = TiledParser
      .findLayer(inventoryLayerRef, 'background');
    final bgObjects = backgroundLayer.objects;

    // render inventory background
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

/*
   TODO: Add support for dropping an item on the floor
   TODO: When loot drops on the floor, ensure that it 
   does not drop utside of a traversable position.
 */
class InventoryDragAndDropPrototype {
  static final NULL_PICKUP_ID = 'NO_ITEM_PICKED_UP';
  static public final state = {
    initialized: false,
    invGrid: Grid.create(16 * Hud.rScale),
    equipmentSlots: new Array<EquippableSlotMeta>(),
    debugGrid: Grid.create(16 * Hud.rScale),
    pickedUpItemId: NULL_PICKUP_ID,
    itemsById: [
      NULL_PICKUP_ID => Loot.createInstance(
          ['nullItem'], NULL_PICKUP_ID)
    ],
    interactSlots: new Array<h2d.Interactive>()
  };

  static public function getEquippedAbilities() {
    return state.equipmentSlots;
  }

  static public function getItemById(id: String) {
    return state.itemsById.get(id);
  }

  static public function addItemToInventory(
      cx, cy, slotWidth, slotHeight, lootInstance) {
     
    Grid.setItemRect(
        state.invGrid, 
        cx, cy, slotWidth, slotHeight, lootInstance.id);
    state.itemsById.set(lootInstance.id, lootInstance);
  }

  static function addTestItems(slotSize) {
    final addItemToInv = (
        slotX, slotY, lootInst) -> {
      final lootDef = Loot.getDef(lootInst.type);
      final spriteData = SpriteBatchSystem.getSpriteData(
          Main.Global.uiSpriteBatch,
          lootDef.spriteKey);
      final slotWidth = toSlotSize(spriteData.sourceSize.w);
      final slotHeight = toSlotSize(spriteData.sourceSize.h);

      Grid.setItemRect(
          state.invGrid,
          slotX + slotWidth / 2,
          slotY + slotHeight / 2,
          slotWidth,
          slotHeight,
          lootInst.id);
      state.itemsById.set(
          lootInst.id, 
          lootInst);
    }

    {
      final slotX = 0 * slotSize;
      final slotY = 4 * slotSize;
      // add mock items
      addItemToInv(
          slotX,
          slotY,
          Loot.createInstance([
            Loot.lootDefinitions[0].type
          ]));
    }

    {
      final slotX = 3 * slotSize;
      final slotY = 5 * slotSize;
      // add mock items
      addItemToInv(
          slotX,
          slotY,
          Loot.createInstance([
            Loot.lootDefinitions[1].type
          ]));
    }

    {
      final slotX = 1 * slotSize;
      final slotY = 8 * slotSize;
      // add mock items
      addItemToInv(
          slotX,
          slotY,
          Loot.createInstance([
            Loot.lootDefinitions[2].type
          ]));
    }
  }

  static function prepareEquipmentSlots() {
    final hudLayoutRef = TiledParser.loadFile(
        hxd.Res.ui_hud_layout_json); 
    final inventoryLayerRef = TiledParser
      .findLayer(hudLayoutRef, 'inventory');
    final interactRef = TiledParser
      .findLayer(
          inventoryLayerRef, 'interactable');
    final equipmentSlots = Lambda.filter(
        interactRef.objects,
        (o) -> o.type == 'equipment_slot');  

    state.equipmentSlots = Lambda.map(
        equipmentSlots, (slot) -> {
          final allowedCategory = Lambda.find(
              slot.properties, 
              (prop: {
                name: String,
                value: String
              }) -> prop.name == 'allowedCategory')
            .value;

          return {
            equippedItemId: NULL_PICKUP_ID,
            allowedCategory: allowedCategory,
            x: slot.x * Hud.rScale,
            y: slot.y * Hud.rScale,
            width: slot.width * Hud.rScale,
            height: slot.height * Hud.rScale
          }
        });
  }

  static function toSlotSize(value) {
    return Math.ceil(value / 16) * 16 * Hud.rScale;
  }

  public static function update(dt) {
    final slotSize = 16 * Hud.rScale;

    // handle interact slots
    {
      // cleanup
      if (!Main.Global.uiState.inventory.opened) {
        Main.Global.worldMouse.hoverState = 
          Main.HoverState.None;
        for (interact in state.interactSlots) {
          interact.remove();
        }
        state.interactSlots = [];
      } else if (state.interactSlots.length == 0) {
        final tiledInteractables = {
          final hudLayoutRef = TiledParser.loadFile(
              hxd.Res.ui_hud_layout_json); 
          final inventoryLayerRef = TiledParser
            .findLayer(hudLayoutRef, 'inventory');
          final interactRef = TiledParser
            .findLayer(
                inventoryLayerRef, 'interactable');
          interactRef.objects; 
        }

        state.interactSlots = Lambda.map(
            tiledInteractables, 
            (ti) -> {
              final interact = new h2d.Interactive(
                  ti.width * Hud.rScale,
                  ti.height * Hud.rScale,
                  Main.Global.uiRoot);
              
              interact.propagateEvents = true;
              interact.x = ti.x * Hud.rScale;
              interact.y = ti.y * Hud.rScale;

              interact.onOver = (ev: hxd.Event) -> {
                Main.Global.worldMouse.hoverState = 
                  Main.HoverState.Ui;
              }

              interact.onOut = (ev: hxd.Event) -> {
                Main.Global.worldMouse.hoverState = 
                  Main.HoverState.None;
              }

              interact;
            });
      }
    }

    if (!Main.Global.uiState.inventory.opened) {
      return;
    }

    if (!state.initialized) {
      state.initialized = true;

      prepareEquipmentSlots();
      addTestItems(slotSize);
    }

    // handle slot interactions
    {
      final pickedUpId = Utils.withDefault(
          state.pickedUpItemId,
          NULL_PICKUP_ID);
      final lootInst = state.itemsById.get(pickedUpId);
      final lootDef = Loot.getDef(lootInst.type);
      final spriteData = SpriteBatchSystem.getSpriteData(
          Main.Global.uiSpriteBatch,
          lootDef.spriteKey);
      final slotWidth = toSlotSize(spriteData.sourceSize.w);
      final slotHeight = toSlotSize(spriteData.sourceSize.h);
      final pickedUpItem = {
        slotWidth: slotWidth,
        slotHeight: slotHeight,
      };
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
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
      final rectOriginX = mx - halfWidth;
      final rectOriginY = my - halfHeight;
      final mouseSlotX = Math.round(rectOriginX / slotSize) * slotSize;
      final mouseSlotY = Math.round(rectOriginY / slotSize) * slotSize;
      final cx = mouseSlotX + halfWidth;
      final cy = mouseSlotY + halfHeight;
      final hasPickedUp = state.pickedUpItemId != NULL_PICKUP_ID;
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
      final pickedUpItemBounds = new h2d.col.Bounds();
      pickedUpItemBounds.set(
          mouseSlotX, mouseSlotY, w, h);
      final inventoryBounds = new h2d.col.Bounds();
      inventoryBounds.set(
          slotDefinition.x * Hud.rScale, 
          slotDefinition.y * Hud.rScale, 
          slotDefinition.width * Hud.rScale, 
          slotDefinition.height * Hud.rScale);

      // check collision with equipment slots
      final handleEquipmentSlots = () -> {
        final nearestAbilitySlot = Lambda.fold(
            state.equipmentSlots, 
            (slot, result: {
              matchedSlot: EquippableSlotMeta,
              distance: Float
            }) -> {
              final colSlot = new h2d.col.Bounds();
              colSlot.set(slot.x, slot.y, slot.width, slot.height);
              final colSlotCenter = colSlot.getCenter();
              final colPickedUp = new h2d.col.Bounds();
              colPickedUp.set(
                  mx - pickedUpItem.slotWidth / 2, 
                  my - pickedUpItem.slotHeight / 2, 
                  pickedUpItem.slotWidth, 
                  pickedUpItem.slotHeight);
              final colPickedUpCenter = colPickedUp.getCenter();
              final distBetweenCollisions = Utils.distance(
                  colSlotCenter.x,
                  colSlotCenter.y,
                  colPickedUpCenter.x,
                  colPickedUpCenter.y);

              if (colSlot.intersects(colPickedUp) && 
                  distBetweenCollisions < result.distance) {

                return {
                  matchedSlot: slot,
                  distance: distBetweenCollisions
                };
              }

              return result;
            }, {
              matchedSlot: null,
              distance: Math.POSITIVE_INFINITY
            }).matchedSlot;

        if (nearestAbilitySlot != null) {
          final canEquip = lootDef.category == 
            nearestAbilitySlot.allowedCategory ||
            state.pickedUpItemId == NULL_PICKUP_ID;

          final highlightSlotToEquip = (time) -> {
            Main.Global.uiSpriteBatch.emitSprite(
                nearestAbilitySlot.x, 
                nearestAbilitySlot.y,
                'ui/square_white',
                null,
                (p) -> {
                  p.sortOrder = 3;
                  final b = p.batchElement;
                  b.scaleX = nearestAbilitySlot.width;
                  b.scaleY = nearestAbilitySlot.height;
                  b.a = 0.6;

                  if (canEquip) {
                    b.b = 0;
                    // show red to indicate not-allowed
                  } else {
                    b.r = 214 / 255;
                    b.g = 0;
                    b.b = 0;
                  }
                });

            return false;
          };

          if (hasPickedUp) {
            Main.Global.renderHooks.push(
                highlightSlotToEquip);
          }

          if (canEquip && 
              Main.Global.worldMouse.clicked) {
            // swap currently equipped with item at pointer
            final originallyEquipped = nearestAbilitySlot.equippedItemId;
            nearestAbilitySlot.equippedItemId = lootInst.id;
            state.pickedUpItemId = Utils.withDefault(
                originallyEquipped,
                NULL_PICKUP_ID);
          }
        }
      };

      handleEquipmentSlots();

      Grid.removeItem(
          state.debugGrid, 
          'item_can_place');

      Grid.removeItem(
          state.debugGrid, 
          'item_cannot_place');

      final isInBounds = {
        final pib = pickedUpItemBounds;
        final intersects = inventoryBounds
          .intersects(pib);
        // we subtract 1 from the max values since the algorithm
        // calculates it as if the positions are in grid units
        final cornerPoints = [
          new h2d.col.Point(pib.xMin, pib.yMin),
          new h2d.col.Point(pib.xMin, pib.yMax - 1),
          new h2d.col.Point(pib.xMax - 1, pib.yMax - 1),
          new h2d.col.Point(pib.xMax - 1, pib.yMin),
        ];

        intersects && 
          Lambda.foreach(cornerPoints, (pt) -> {
            return inventoryBounds.contains(pt);
          });
      };

      // translate position so so the grid's 0,0 is relative to the slotDefinition
      final tcx = cx - toSlotSize(slotDefinition.x);
      final tcy = cy - toSlotSize(slotDefinition.y);
      final canPlace = isInBounds && 
        Lambda.count(
          Grid.getItemsInRect(
            state.invGrid,
            tcx,
            tcy,
            w,
            h)) <= 1;

      if (Main.Global.worldMouse.clicked) {
        final currentlyPickedUpItem = state.pickedUpItemId;

        if (canPlace) {
          final getFirstKey = (keys: Iterator<GridKey>) -> {
            for (k in keys) {
              return k;
            }
            return NULL_PICKUP_ID;
          }

          final itemIdAtPosition = getFirstKey(
              Grid.getItemsInRect(
                state.invGrid,
                tcx,
                tcy,
                w, h).keys());

          Grid.removeItem(
              state.invGrid,
              itemIdAtPosition);

          state.pickedUpItemId = itemIdAtPosition;
        }

        final shouldPlace = hasPickedUp && canPlace;
        if (shouldPlace) {
          Grid.setItemRect(
              state.invGrid,
              tcx,
              tcy,
              w, h,
              currentlyPickedUpItem);
        }
      }

      /* 
         Represents the interaction status. So we can render different
         cursor styles depending upon what inventory interaction
         area you are on.
       */
      if (isInBounds) {
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

    final hasPickedUp = state.pickedUpItemId != NULL_PICKUP_ID;
    final shouldDropItem = hasPickedUp && 
      Main.Global.worldMouse.hoverState == 
        Main.HoverState.None;

    if (shouldDropItem) {
      state.pickedUpItemId = NULL_PICKUP_ID;
      Main.Global.worldMouse.hoverState = Main.HoverState.Ui;
      // final playerRef = Entity.getById('PLAYER');
      // final lootInst = state.itemsById
      //   .get(state.pickedUpItemId);
      // final lootDef = Loot.getDef(lootInst.type);
      // Game.createLootRef(
      //     playerRef.x, 
      //     playerRef.y, 
      //     [])
    }
  }

  public static function render(time) {
    if (!Main.Global.uiState.inventory.opened) {
      return;
    }

    final cellSize = state.invGrid.cellSize;

    final renderEquippedItem = (abilitySlot) -> {
      final equippedLootInst = state.itemsById.get(
          abilitySlot.equippedItemId);

      if (equippedLootInst != null) {
        final lootDef = Loot.getDef(equippedLootInst.type);
        Main.Global.uiSpriteBatch.emitSprite(
            abilitySlot.x + abilitySlot.width / 2,  
            abilitySlot.y + abilitySlot.height / 2,
            lootDef.spriteKey,
            null,
            (p) -> {
              final b = p.batchElement;
              p.sortOrder = 2;
              b.scale = Hud.rScale;
            });
      }
    };

    for (slot in state.equipmentSlots) {
      renderEquippedItem(slot);
    }

    // render inventory items
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
    for (itemId => bounds in state.invGrid.itemCache) {
      final lootInst = state.itemsById.get(itemId);
      final lootDef = Loot.getDef(lootInst.type);
      final width = bounds[1] - bounds[0];
      final height = bounds[3] - bounds[2];
      final screenCx = (bounds[0] + width / 2) * cellSize;
      final screenCy = (bounds[2] + height / 2) * cellSize;
      // translate position to inventory position
      final invCx = screenCx + toSlotSize(slotDefinition.x);
      final invCy = screenCy + toSlotSize(slotDefinition.y);

      Main.Global.uiSpriteBatch.emitSprite(
          invCx,
          invCy,
          lootDef.spriteKey,
          (p) -> {
            p.sortOrder = 1;
            final b = p.batchElement;
            b.scale = Hud.rScale;
          });
    } 

    // render slot highlights (shows if you may drop/equip at given slot)
    for (itemId => bounds in state.debugGrid.itemCache) {
      final width = bounds[1] - bounds[0];
      final height = bounds[3] - bounds[2];
      final cx = bounds[0] + width / 2;
      final cy = bounds[2] + height / 2;

      Main.Global.uiSpriteBatch.emitSprite(
          (cx - width / 2) * cellSize, (cy - height / 2) * cellSize,
          'ui/square_white',
          (p) -> {
            p.sortOrder = 2;

            final b = p.batchElement;
            b.scaleX = width * cellSize;
            b.scaleY = height * cellSize;
            b.alpha = 0.4;

            if (itemId == 'item_can_place') {
              b.r = 99 / 255;
              b.g = 199 / 255;
              b.b = 77 / 255;
            }

            if (itemId == 'item_cannot_place') {
              b.r = 214 / 255;
              b.g = 0;
              b.b = 0;
            }
          });
    } 

    // render picked up item
    if (state.pickedUpItemId != NULL_PICKUP_ID) {
      final lootInst = state.itemsById.get(state.pickedUpItemId);
      final lootDef = Loot.getDef(lootInst.type);
      final spriteData = SpriteBatchSystem.getSpriteData(
          Main.Global.uiSpriteBatch,
          lootDef.spriteKey);
      final w = toSlotSize(spriteData.sourceSize.w);
      final h = toSlotSize(spriteData.sourceSize.h);
      final x = Main.Global.uiRoot.mouseX;
      final y = Main.Global.uiRoot.mouseY;

      Main.Global.uiSpriteBatch.emitSprite(
          x, y,
          lootDef.spriteKey,
          (p) -> {
            p.sortOrder = 4;

            final b = p.batchElement;
            b.scale = Hud.rScale;
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
    final inventoryLayerRef = TiledParser
      .findLayer(uiLayoutRef, 'inventory');
    final hudEquippedAbilitySlots = TiledParser
      .findLayer(hudLayer, 'equipped_ability_slots')
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

    // render equipped abilities
    {
      final spriteEffect = (p) -> {
        p.batchElement.scaleX = rScale * 1.0;
        p.batchElement.scaleY = rScale * 1.0;
      };
      final inventoryEquippedSlots = InventoryDragAndDropPrototype
          .getEquippedAbilities();

      for (i in 0...inventoryEquippedSlots.length) {
        final s = inventoryEquippedSlots[i];
        final hudSlot = hudEquippedAbilitySlots[i];
        final cx = (hudSlot.x + hudSlot.width / 2) * Hud.rScale;
        final cy = (hudSlot.y + hudSlot.height / 2) * Hud.rScale;
        final lootId = s.equippedItemId;
        final lootInst = InventoryDragAndDropPrototype
          .getItemById(lootId); 
        final lootDef = Loot.getDef(lootInst.type);

        Main.Global.uiSpriteBatch.emitSprite(
            cx, cy,
            lootDef.spriteKey,
            null,
            spriteEffect);
      }
    }
  }
}
