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
typedef SortedHudResourceBars = Array<String>;
private typedef EquippableSlotMeta = {
  equippedItemId: String,
  allowedCategory: Loot.LootDefCat,
  // slot dimensions and ui position
  x: Int,
  y: Int,
  width: Int,
  height: Int,
}

class UiStateManager {
  public static function noopCompleteCallback(_, _) {
  }

  public static function send(
      action: UiAction,
      ?onCompleteCalback: (
        successValue: Dynamic, 
        error: Dynamic) -> Void) {
    final onComplete = Utils.withDefault(
        onCompleteCalback, 
        noopCompleteCallback);
    final uiState = Main.Global.uiState;

    switch(action) {
      case { type: 'INVENTORY_TOGGLE' }: {
        final s = uiState.inventory;

        if (!s.enabled) {
          Main.Global.clearUi((field) -> field != 'hud');
        }

        s.enabled = !s.enabled;
      }

      case { type: 'PASSIVE_SKILL_TREE_TOGGLE' }: {
        final s = uiState.passiveSkillTree;

        if (!s.enabled) {
          Main.Global.clearUi((field) -> field != 'hud');
        }

        s.enabled = !s.enabled;
      }

      case { 
        type: 'START_GAME',
        data: gameState
      }: {
        Main.Global.gameState = gameState;
        Main.Global.clearUi((field) -> {
          return field != 'hud';
        });

        Main.Global.replaceScene( 
            () -> {
              final gameInstance = new Game(Main.Global.rootScene); 
              return () -> gameInstance.remove();
            });

        Hud.InventoryDragAndDropPrototype
          .addTestItems();

        Session.logAndProcessEvent(
            gameState,
            Session.makeEvent(
              'GAME_LOADED'));
      }

      case { 
        type: 'DELETE_GAME',
        data: gameId
      }: {
        try {
          Session.deleteGame(gameId); 
          onComplete(null, null);
        } catch (err) {
          onComplete(null, err);
        }
      }

      case { 
        type: 'SWITCH_SCENE',
        data: sceneName
      }: {
        final Global = Main.Global;
        Main.Global.clearUi((field) -> true);

        Global.replaceScene(() -> {
          return  switch(sceneName) {
            case 'experiment': Experiment.init();
            case 'editor': Editor.init();
            case 'exit': Main.onGameExit();
            default: {
              throw 'home screen menu case not handled';
            };
          }
        });
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
  public static function inventorySlotAutoAddItem(
      itemInstance: Loot.LootInstance): Bool {
    final slotSize = 16;
    // convert item dimensions to slot units 
    final lootDef = Loot.getDef(itemInstance.type);
    final spriteData = SpriteBatchSystem.getSpriteData(
        Main.Global.uiSpriteBatch.batchManager.spriteSheetData,
        lootDef.spriteKey);
    final pixelWidth = spriteData.sourceSize.w;
    final pixelHeight = spriteData.sourceSize.h;
    final sw = Math.ceil(pixelWidth / slotSize);
    final sh = Math.ceil(pixelHeight / slotSize);
    final INVENTORY_RECT = InventoryDragAndDropPrototype.INVENTORY_RECT;
    final maxCol = Std.int(INVENTORY_RECT.width / slotSize / Hud.rScale);
    final maxRow = Std.int(INVENTORY_RECT.height / slotSize / Hud.rScale);
    final maxY = maxRow - 1;
    final maxX = maxCol - 1;
    final cellSize = Main.Global.gameState.inventoryState.invGrid.cellSize;

    // look for nearest empty cell and put item in if available
    for (y in 0...maxRow) {
      for (x in 0...maxCol) {
        final cx = x + Math.floor(sw / 2);
        final cy = y + Math.floor(sh / 2);
        final filledSlots = Grid.getItemsInRect(
            Main.Global.gameState.inventoryState.invGrid, 
            x * cellSize + (sw / 2) * cellSize, 
            y * cellSize + (sh / 2) * cellSize, 
            Std.int(sw * cellSize),
            Std.int(sh * cellSize));
        final canFit = Lambda.count(
            filledSlots) == 0
          && cx - Math.floor(sw / 2) >= 0
          && cx + Math.floor(sw / 2) <= maxX + 1
          && cy + Math.floor(sh / 2) <= maxY + 1
          && cy - Math.floor(sh / 2) >= 0;

        // add success
        if (canFit) {
          Session.logAndProcessEvent(
              Main.Global.gameState, 
              Session.makeEvent(
                'INVENTORY_INSERT_ITEM', {
                  x: x * cellSize + (sw / 2) * cellSize, 
                  y: y * cellSize + (sh / 2) * cellSize, 
                  width: sw * cellSize,
                  height: sh * cellSize,
                  lootInstance: itemInstance
                }));
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

      final hoveredId = Main.Global.hoveredEntity.id;
      final lootRef = Entity.getById(hoveredId);
      final playerRef = Entity.getById('PLAYER');
      final isPickupMode = lootRef.type == 'LOOT' &&
        (Main.Global.worldMouse.buttonDownStartedAt >
         Main.Global.hoveredEntity.hoverStart);
      final distFromPlayer = Utils.distance(
          playerRef.x, playerRef.y, lootRef.x, lootRef.y);
      final playerCanPickupItem = isPickupMode && 
        distFromPlayer <= playerRef.stats.pickupRadius;
      if (playerCanPickupItem) {
        final cds = Entity.getById('PLAYER').cds;

        if (Main.Global.worldMouse.buttonDown == 0) {
          Cooldown.set(
              cds,
              'playerCanPickupItem',
              4/100);
        }

        final pickupItemButtonClicked = 
          Main.Global.worldMouse.clicked;
        if (pickupItemButtonClicked) {
          Cooldown.set(
              cds,
              'playerCanPickupItem',
              0);

          final size = lootRef.radius * 2;
          final addSuccess = Inventory
            .inventorySlotAutoAddItem(
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
    final inventorState = Main.Global.uiState.inventory;

    if (!inventorState.enabled) {
      return;
    }

    final hudLayoutData: Editor.EditorState = SaveState.load(
        Hud.HUD_LAYOUT_FILE,
        false);

    if (hudLayoutData == null) {
      return;
    }

    final inventoryLayerGrid = hudLayoutData.gridByLayerId.get(
        'layer_2');
    final uiBackgroundObjects = [
      'ability_slots_group_background',
      'ui_inventory_underlay',
    ];
    for (objectId in uiBackgroundObjects) {
      final bounds = inventoryLayerGrid.itemCache.get(
          objectId);
      final editorConfig = Editor.getConfig(Hud.HUD_LAYOUT_FILE);
      final objectMeta = editorConfig.objectMetaByType.get(
          objectId);

      final cx = bounds[0];
      final cy = bounds[2];
      Main.Global.uiSpriteBatch.emitSprite(
          cx * Hud.rScale,
          cy * Hud.rScale,
          objectMeta.spriteKey, 
          null,
          (p) -> {
            p.sortOrder = 0;
            p.scale = Hud.rScale;
          });
    }
  }
}

// handles interaction elements
class UiGrid {
  static var colGrid = Grid.create(1);
  static final iList: Array<h2d.Interactive> = [];
  static final NULL_HOVERED_ID = 'NULL_HOVERED_ID';
  static var state = {
    hoveredId: NULL_HOVERED_ID,
  };
  static var tfPlayerLevel: h2d.Text;

  public static function loadHudLayout(): Editor.EditorState {
    return SaveState.load(
        Hud.HUD_LAYOUT_FILE,
        false,
        null,
        (_) -> {},
        (_) -> {});
  }

  public static function update(dt: Float) {
    if (!Main.Global.uiState.hud.enabled) {
      return;
    }

    final hudLayoutRef = loadHudLayout();
    if (hudLayoutRef == null) {
      return;
    }

    final isInteractInitialized = iList.length != 0;

    if (isInteractInitialized) {
      return;
    }

    for (grid in hudLayoutRef.gridByLayerId) {
      for (objectId => bounds in grid.itemCache) {
        final editorConfig = Editor.getConfig(Hud.HUD_LAYOUT_FILE);
        final objectType = hudLayoutRef.itemTypeById.get(objectId);
        final objectMeta = editorConfig.objectMetaByType.get(objectType);
        final bm = Main.Global.uiSpriteBatch.batchManager;
        final spriteData = SpriteBatchSystem.getSpriteData(
            bm.spriteSheetData,
            objectMeta.spriteKey);
        final ss = spriteData.sourceSize;
        final width  = ss.w * Hud.rScale;
        final height = ss.h * Hud.rScale;
        final x = bounds[0] * Hud.rScale;
        final y = bounds[2] * Hud.rScale;

        if (Main.Global.uiState.hud.enabled 
            && objectMeta.type == 'UI_ELEMENT') {
          final iRef = new h2d.Interactive(
              width,
              height,
              Main.Global.uiRoot);
          iRef.x = x;
          iRef.y = y;

          iRef.onOver = (e: hxd.Event) -> {
            state.hoveredId = objectId;
          };

          iRef.onOut = (e: hxd.Event) -> {
            state.hoveredId = NULL_HOVERED_ID;
          };

          for (p in Reflect.fields(objectMeta.data)) {
            final value = Reflect.field(objectMeta.data, p);
            switch(p) {
              case 'onClick': {
                iRef.onClick = (e: hxd.Event) -> {
                  UiStateManager.send({
                    type: value
                  });
                }
              }
              default: {}
            }
          }

          iList.push(iRef); 
        }
      }
    }
  }

  public static function render(time: Float) {
    final ps = Entity.getById('PLAYER').stats;

    if (ps == null || !Main.Global.uiState.hud.enabled) {
      return;
    }

    final editorConfig = Editor.getConfig(Hud.HUD_LAYOUT_FILE);
    final hudLayoutRef = loadHudLayout();
    final orderedLayers = hudLayoutRef.layerOrderById;

    // render hud buttons
    {
      final cockpitLayer = 'layer_1';
      final grid = hudLayoutRef.gridByLayerId.get(cockpitLayer);

      for (objectId => bounds in grid.itemCache) {
        final editorConfig = Editor.getConfig(Hud.HUD_LAYOUT_FILE);
        final objectType = hudLayoutRef.itemTypeById.get(objectId);
        final objectMeta = editorConfig.objectMetaByType.get(objectType);
        final x = bounds[0] * Hud.rScale;
        final y = bounds[2] * Hud.rScale;
        final hoverSprite = objectMeta.data.hoverSprite;
        final isHovered = state.hoveredId == objectId;
        final spriteKey = (isHovered
            && hoverSprite != null)
          ? hoverSprite
          : objectMeta.spriteKey;
        final ref = Main.Global.uiSpriteBatch.emitSprite(
            x,
            y,
            spriteKey);
        ref.sortOrder = 1;
        ref.scale = Hud.rScale;

        final shouldHighlightSkillTreeButton = 
          objectType == 'hud_passive_skill_tree_button' 
          && PassiveSkillTree.calcNumUnusedPoints(
              Main.Global.gameState) > 0;
        if (shouldHighlightSkillTreeButton) {
          final progress = Math.abs(Math.sin(Main.Global.time * 6));
          ref.y -= progress * 6;
          ref.r = 0.5 + 0.5 * progress;
          ref.g = 0.4 + 0.5 * progress;
          ref.b = 0.;
        }
      }
    }

    // render hud resource bars
    {
      final resourceBarsLayer = 'layer_2';
      final grid = 
        hudLayoutRef.gridByLayerId.get(resourceBarsLayer);
      final sortedHealthBars: 
        SortedHudResourceBars = [];
      final sortedEnergyBars: 
        SortedHudResourceBars = [];

      for (objectId in grid.itemCache.keys()) {
        final objectType = hudLayoutRef.itemTypeById.get(objectId);
        final isHealthBarNode = objectType == 'cockpit_health_bar_node';
        final isEnergyBarNode = objectType == 'cockpit_energy_bar_node';

        if (isHealthBarNode || isEnergyBarNode) {
          if (isHealthBarNode) {
            sortedHealthBars.push(objectId);
          }

          if (isEnergyBarNode) {
            sortedEnergyBars.push(objectId);
          }
        }
      }

      function sortByX(idA, idB, flip = false) {
        final boundsA = grid.itemCache.get(idA);
        final xA = boundsA[0];
        final boundsB = grid.itemCache.get(idB);
        final xB = boundsB[0];

        if (flip) {
          if (xA > xB) {
            return -1;
          }

          if (xA < xB) {
            return 1;
          }
        } else {
          if (xA < xB) {
            return -1;
          }

          if (xA > xB) {
            return 1;
          }
        }

        return 0;
      }

      function renderResourceBar(
          numSegments,
          resourceBars: SortedHudResourceBars) {
        for (i in 0...numSegments) {
          final objectId = resourceBars[i];
          final editorConfig = Editor.getConfig(Hud.HUD_LAYOUT_FILE);
          final objectType = hudLayoutRef.itemTypeById.get(objectId);
          final objectMeta = editorConfig
            .objectMetaByType
            .get(objectType);
          final bounds = grid.itemCache.get(objectId);
          final x = bounds[0] * Hud.rScale;
          final y = bounds[2] * Hud.rScale;
          final ref = Main.Global.uiSpriteBatch.emitSprite(
              x,
              y,
              objectMeta.spriteKey);
          ref.sortOrder = 2;
          ref.scale = Hud.rScale;
        }
      }

      {
        final healthRemaining =
          ps.currentHealth / ps.maxHealth;
        final numSegments = Math.ceil(
            healthRemaining * sortedHealthBars.length);

        sortedHealthBars.sort(
            (a, b) -> sortByX(a, b, true));
        renderResourceBar(numSegments, sortedHealthBars);
      }

      {
        final energyRemaining =
          ps.currentEnergy / ps.maxEnergy;
        final numSegments = Math.ceil(
            energyRemaining * sortedEnergyBars.length);

        sortedEnergyBars.sort(
            (a, b) -> sortByX(a, b));
        renderResourceBar(numSegments, sortedEnergyBars);
      }
    }

    // render hud experience progress
    {
      final experienceProgressLayer = 'layer_2';
      final grid = 
        hudLayoutRef.gridByLayerId.get(experienceProgressLayer);
      final objectId = 'hud_experience_progress';
      final bounds = grid.itemCache.get(objectId); 
      final objectType = hudLayoutRef.itemTypeById.get(objectId);
      final objectMeta = editorConfig
        .objectMetaByType
        .get(objectType);

      // background sprite
      final spriteRef = Main.Global.uiSpriteBatch.emitSprite(
          bounds[0] * Hud.rScale,
          bounds[2] * Hud.rScale,
          objectMeta.spriteKey);
      spriteRef.sortOrder = 1;
      spriteRef.scale = Hud.rScale;
      spriteRef.r = 0.;
      spriteRef.g = 0.;
      spriteRef.b = 0.;
      spriteRef.a = 0.9;

      // background sprite 'drop shadow'
      final spriteRef = Main.Global.uiSpriteBatch.emitSprite(
          bounds[0] * Hud.rScale,
          (bounds[2] + 1) * Hud.rScale,
          objectMeta.spriteKey);
      spriteRef.sortOrder = 1;
      spriteRef.scale = Hud.rScale;
      spriteRef.r = 0.;
      spriteRef.g = 0.;
      spriteRef.b = 0.;
      spriteRef.a = 0.9;

      final currentExp = Main.Global.gameState.experienceGained;
      final currentLevel = Config.calcCurrentLevel(
          currentExp);
      final nextLevel = currentLevel + 1;
      final currentLevelExpRequirement = Config.levelExpRequirements[currentLevel];
      final nextLevelExpRequirement = Config.levelExpRequirements[nextLevel];
      final expDiffBetweenCurrentAndNextLevel = nextLevelExpRequirement 
        - currentLevelExpRequirement;
      final expUntilNextLevel = nextLevelExpRequirement - currentExp;
      final levelProgress = expUntilNextLevel 
        / expDiffBetweenCurrentAndNextLevel;

      Main.Global.logData.levelInfo = [
        currentLevel, 
        currentExp,
        expUntilNextLevel,
        Config.levelExpRequirements.slice(0, 5)];

      // experience progress sprite
      final spriteRef = Main.Global.uiSpriteBatch.emitSprite(
          bounds[0] * Hud.rScale,
          bounds[2] * Hud.rScale,
          objectMeta.spriteKey);
      spriteRef.sortOrder = 1;
      spriteRef.scale = Hud.rScale;
      spriteRef.scaleX *= 1 - levelProgress;
      spriteRef.r = 1.;
      spriteRef.g = 0.7;
      spriteRef.b = 0.;
    }

    // render hud player level
    {
      final playerLevelLayer = 'layer_2';
      final grid = 
        hudLayoutRef.gridByLayerId.get(playerLevelLayer);
      final objectId = 'hud_player_level';
      final bounds = grid.itemCache.get(objectId); 
      final objectType = hudLayoutRef.itemTypeById.get(objectId);
      final objectMeta = editorConfig
        .objectMetaByType
        .get(objectType);

      final tfPlayerLevel = TextPool.get();
      tfPlayerLevel.font = Fonts.title();
      Main.Global.uiRoot.addChild(tfPlayerLevel);
      tfPlayerLevel.text = Std.string(
          Config.calcCurrentLevel(
            Main.Global.gameState.experienceGained) + 1);
      tfPlayerLevel.x = bounds[0] * Hud.rScale;
      tfPlayerLevel.y = bounds[2] * Hud.rScale - tfPlayerLevel.textHeight / 2;
      tfPlayerLevel.textAlign = Center;
      tfPlayerLevel.textColor = 0xffffff;
    }
  }
}

class Tooltip {
  static var tooltipTextRef: h2d.Text;

  public static function update(dt: Float) {
    final initialized = tooltipTextRef != null;

    if (!initialized) {
      final font = Fonts.primary().clone();
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
          p.scaleX = ttPaddingH + 
            tooltipTextRef.textWidth / Hud.rScale;
          p.scaleY = ttPaddingV + 
            tooltipTextRef.textHeight / Hud.rScale;
          p.r = 0;
          p.g = 0;
          p.b = 0;
          p.a = 0.9;
        });
  }
}

/*
   TODO: When loot drops on the floor, ensure that it 
   does not drop utside of a traversable position.
 */
class InventoryDragAndDropPrototype {
  
  static final slotSize = 16;
  public static final NULL_PICKUP_ID = 'NO_ITEM_PICKED_UP';
  static final NULL_LOOT_INSTANCE = Loot.createInstance(
      ['nullItem'], NULL_PICKUP_ID);
  static public final state = {
    equippedAbilitiesById: new haxe.ds.Vector<String>(3),
    itemsById: [
      NULL_PICKUP_ID => NULL_LOOT_INSTANCE
    ],
    invGrid: Grid.create(16),
    initialized: false,
    debugGrid: Grid.create(16),
    pickedUpItemId: NULL_PICKUP_ID,
    pickedUpInstance: NULL_LOOT_INSTANCE,
    interactSlots: new Array<h2d.Interactive>(),
    nearestAbilitySlot: {
      slotDefinition: null,
      slotIndex: -1,
      distance: Math.POSITIVE_INFINITY
    },
    slotHovered: false
  };

  static public function getEquippedAbilities() {
    return state.equippedAbilitiesById;
  }

  static public function getItemById(id: String) {
    return Main.Global.gameState.inventoryState.itemsById.get(id);
  }

  static public function equipItemToSlot(
      lootInst: Loot.LootInstance, 
      index) {

    state.equippedAbilitiesById[index] = lootInst.id;
    Main.Global.gameState.inventoryState.itemsById.set(lootInst.id, lootInst);

  }

  static public function addTestItems() {
    final createLootInstanceByType = (type: Loot.LootDefType) -> {
      return Loot.createInstance([type]);
    };

    equipItemToSlot(
        createLootInstanceByType('spiderBots'), 0); 

    equipItemToSlot(
        createLootInstanceByType('channelBeam'), 1); 

    equipItemToSlot(
        createLootInstanceByType('energy1'), 2); 

    equipItemToSlot(
        createLootInstanceByType('moveSpeedAura'), 3); 
  }

  static function getEquipmentSlotDefinitions() {
    final slotGap = 1 * Hud.rScale;
    final abilitySlot1 = {
      equippedItemId: NULL_PICKUP_ID,
      allowedCategory: 'ability',
      x: 151 * Hud.rScale,
      y: 32 * Hud.rScale,
      width: 22 * Hud.rScale,
      height: 22 * Hud.rScale,
    };
    final abilitySlot2 = {
      equippedItemId: NULL_PICKUP_ID,
      allowedCategory: 'ability',
      x: abilitySlot1.x + abilitySlot1.width + slotGap,
      y: abilitySlot1.y,
      width: abilitySlot1.width,
      height: abilitySlot1.height,
    };
    final abilitySlot3 = {
      equippedItemId: NULL_PICKUP_ID,
      allowedCategory: 'ability',
      x: abilitySlot2.x + abilitySlot2.width + slotGap,
      y: abilitySlot2.y,
      width: abilitySlot1.width,
      height: abilitySlot1.height,
    };
    final abilitySlot4 = {
      equippedItemId: NULL_PICKUP_ID,
      allowedCategory: 'ability',
      x: abilitySlot3.x + abilitySlot3.width + slotGap,
      y: abilitySlot3.y,
      width: abilitySlot1.width,
      height: abilitySlot1.height,
    };

    return [
      abilitySlot1,
      abilitySlot2,
      abilitySlot3,
      abilitySlot4
    ];
  }

  public static final INVENTORY_RECT = {
    equippedItemId: NULL_PICKUP_ID,
    allowedCategory: 'any',
    x: 256 * Hud.rScale,
    y: 32 * Hud.rScale,
    width: 192 * Hud.rScale,
    height: 160 * Hud.rScale
  }

  static function toSlotSize(value) {
    return Math.ceil(value / 16) * slotSize;
  }

  static function hasPickedUp() {
    return state.pickedUpItemId != NULL_PICKUP_ID;
  }

  public static function update(dt) {
    final hudLayoutData: Editor.EditorState = SaveState.load(
        Hud.HUD_LAYOUT_FILE,
        false);

    if (hudLayoutData == null) {
      return;
    }

    if (state.slotHovered) {
      Main.Global.worldMouse.hoverState = 
        Main.HoverState.Ui;
    }

    // handle interact slots
    {
      // cleanup
      if (!Main.Global.uiState.inventory.enabled) {
        for (interact in state.interactSlots) {
          interact.remove();
        }
        state.interactSlots = [];
        state.slotHovered = false;
      } else if (state.interactSlots.length == 0) {
        final interactableSlots: Array<Dynamic> = 
          getEquipmentSlotDefinitions()
              .concat([INVENTORY_RECT]);

        state.interactSlots = Lambda.map(
            interactableSlots,
            (ti) -> {
              final interact = new h2d.Interactive(
                  ti.width,
                  ti.height,
                  Main.Global.uiRoot);
              
              interact.propagateEvents = true;
              interact.x = ti.x;
              interact.y = ti.y;

              interact.onOver = (ev: hxd.Event) -> {
                state.slotHovered = true;
              }

              interact.onOut = (ev: hxd.Event) -> {
                state.slotHovered = false;
              }

              interact;
            });
      }
    }

    if (!Main.Global.uiState.inventory.enabled) {
      return;
    }

    if (!state.initialized) {
      state.initialized = true;
    }

    // handle slot interactions
    {
      final pickedUpId = Utils.withDefault(
          state.pickedUpItemId,
          NULL_PICKUP_ID);
      final lootInst = state.pickedUpInstance;
      final lootDef = Loot.getDef(lootInst.type);
      final spriteData = SpriteBatchSystem.getSpriteData(
          Main.Global.uiSpriteBatch.batchManager.spriteSheetData,
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
      final rectOriginX = mx / Hud.rScale - halfWidth;
      final rectOriginY = my / Hud.rScale - halfHeight;
      final mouseSlotX = Math.round(rectOriginX / slotSize) * slotSize;
      final mouseSlotY = Math.round(rectOriginY / slotSize) * slotSize;
      final cx = mouseSlotX + halfWidth;
      final cy = mouseSlotY + halfHeight;
      final pickedUpItemBounds = new h2d.col.Bounds();
      pickedUpItemBounds.set(
          mouseSlotX, mouseSlotY, w, h);
      final inventoryBounds = new h2d.col.Bounds();
      inventoryBounds.set(
          INVENTORY_RECT.x / Hud.rScale, 
          INVENTORY_RECT.y / Hud.rScale, 
          INVENTORY_RECT.width  / Hud.rScale, 
          INVENTORY_RECT.height / Hud.rScale);

      // check collision with equipment slots
      final handleEquipmentSlots = () -> {
        final nearestAbilitySlot = Lambda.foldi(
            getEquipmentSlotDefinitions(), 
            (slot, result: {
              slotDefinition: EquippableSlotMeta,
              slotIndex: Int,
              distance: Float
            }, index) -> {
              final colSlot = new h2d.col.Bounds();
              colSlot.set(
                  slot.x / Hud.rScale, 
                  slot.y / Hud.rScale, 
                  slot.width  / Hud.rScale, 
                  slot.height / Hud.rScale);

              final colSlotCenter = colSlot.getCenter();
              final colPickedUp = new h2d.col.Bounds();
              colPickedUp.set(
                  mx / Hud.rScale - pickedUpItem.slotWidth / 2, 
                  my / Hud.rScale - pickedUpItem.slotHeight / 2, 
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
                  slotDefinition: slot,
                  slotIndex: index,
                  distance: distBetweenCollisions
                };
              }

              return result;
            }, {
              slotDefinition: null,
              slotIndex: -1,
              distance: Math.POSITIVE_INFINITY
            });

        if (nearestAbilitySlot.slotDefinition != null) {
          final canEquip = lootDef.category == 
            nearestAbilitySlot.slotDefinition.allowedCategory ||
            !hasPickedUp();
          if (canEquip && 
              Main.Global.worldMouse.clicked) {
            // swap currently equipped with item at pointer
            final originallyEquipped = state.equippedAbilitiesById[
              nearestAbilitySlot.slotIndex];
            equipItemToSlot(lootInst, nearestAbilitySlot.slotIndex);
            state.pickedUpItemId = Utils.withDefault(
                originallyEquipped,
                NULL_PICKUP_ID);
            state.pickedUpInstance = Main.Global
              .gameState
              .inventoryState
              .itemsById
              .get(state.pickedUpItemId);
          }
        }

        state.nearestAbilitySlot = nearestAbilitySlot;
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
      final tcx = cx - INVENTORY_RECT.x / Hud.rScale;
      final tcy = cy - INVENTORY_RECT.y / Hud.rScale;
      final canPlace = isInBounds && 
        Lambda.count(
          Grid.getItemsInRect(
            Main.Global.gameState.inventoryState.invGrid,
            tcx,
            tcy,
            Std.int(w),
            Std.int(h))) <= 1;

      if (Main.Global.worldMouse.clicked) {
        final currentlyPickedUpItem = state.pickedUpItemId;
        final currentlyPickedUpInstance = state.pickedUpInstance;
        final shouldPlace = hasPickedUp() && canPlace;

        // pickup current item at position
        if (canPlace) {
          final getFirstKey = (keys: Iterator<GridKey>) -> {
            for (k in keys) {
              return k;
            }
            return NULL_PICKUP_ID;
          }

          final itemIdAtPosition = getFirstKey(
              Grid.getItemsInRect(
                Main.Global.gameState.inventoryState.invGrid,
                tcx,
                tcy,
                w, h).keys());

          // grab the data for client-side before it gets
          // oficially removed from the inventory because
          // we'll need it when dropping the item back down
          state.pickedUpItemId = itemIdAtPosition;
          state.pickedUpInstance = Main.Global
            .gameState
            .inventoryState
            .itemsById
            .get(itemIdAtPosition);

          if (itemIdAtPosition != NULL_PICKUP_ID) {
            Session.logAndProcessEvent(
                Main.Global.gameState,
                Session.makeEvent(
                  'INVENTORY_REMOVE_ITEM',
                  itemIdAtPosition));
          }
        }

        // place currently held item to position
        if (shouldPlace) {
          trace('place item');
          Session.logAndProcessEvent(
              Main.Global.gameState,
              Session.makeEvent(
                'INVENTORY_INSERT_ITEM', {
                  x: tcx,
                  y: tcy,
                  width: w, 
                  height: h,
                  lootInstance: currentlyPickedUpInstance
                }));
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

    final itemId = state.pickedUpItemId;
    final canDropItem = hasPickedUp() && 
      (Main.Global.worldMouse.hoverState == 
       Main.HoverState.None);

    if (canDropItem) {
      if (Main.Global.worldMouse.buttonDown == 0) {
        Main.Global.worldMouse.hoverState = Main.HoverState.Ui;
      } else {
        Main.Global.worldMouse.hoverState = Main.HoverState.None;
      }
      final shouldDropItem = Main.Global.worldMouse.buttonDown == 0;

      if (shouldDropItem) {
        final playerRef = Entity.getById('PLAYER');
        final lootInst = state.pickedUpInstance;
        final lootDef = Loot.getDef(lootInst.type);
        final dropRadius = Std.int(
            Utils.clamp(
              playerRef.stats.pickupRadius - 10,
              10, 
              30));
        Game.createLootEntity(
            playerRef.x + Utils.irnd(-dropRadius, dropRadius, true), 
            playerRef.y + Utils.irnd(-dropRadius, dropRadius, true), 
            lootInst);
        Main.Global.gameState.inventoryState.itemsById.remove(state.pickedUpItemId);
        state.pickedUpItemId = NULL_PICKUP_ID;
        state.pickedUpInstance = Main.Global
          .gameState
          .inventoryState
          .itemsById
          .get(state.pickedUpItemId);

        final restoreStateOnMouseRelease = (dt) -> {
          if (Main.Global.worldMouse.buttonDown == -1) {
            Main.Global.worldMouse.hoverState = 
              Main.HoverState.None;
            return false;
          };
          return true;
        }
        Main.Global.updateHooks.push(
            restoreStateOnMouseRelease);
      }
    }
  }

  public static function render(time) {
    final hudLayoutData: Editor.EditorState = SaveState.load(
        Hud.HUD_LAYOUT_FILE,
        false);

    if (hudLayoutData == null) {
      return;
    }

    if (!Main.Global.uiState.inventory.enabled) {
      return;
    }

    final cellSize = Main.Global.gameState.inventoryState.invGrid.cellSize;

    final renderEquippedItem = (itemId, abilitySlot) -> {
      final equippedLootInst = Main.Global.gameState.inventoryState.itemsById.get(
         itemId);

      if (equippedLootInst != null) {
        final lootDef = Loot.getDef(equippedLootInst.type);
        Main.Global.uiSpriteBatch.emitSprite(
            abilitySlot.x + abilitySlot.width / 2,  
            abilitySlot.y + abilitySlot.height / 2,
            lootDef.spriteKey,
            null,
            (p) -> {
              final b = p;
              p.sortOrder = 2;
              b.scale = Hud.rScale;
            });
      }
    };

    final equipmentSlotDefs = getEquipmentSlotDefinitions();
    for (index in 0...state.equippedAbilitiesById.length) {
      final itemId = state.equippedAbilitiesById[index];
      final abilitySlot = equipmentSlotDefs[index];

      renderEquippedItem(itemId, abilitySlot);
    }

    // render inventory items
    for (itemId => bounds in Main.Global.gameState.inventoryState.invGrid.itemCache) {
      final lootInst = Main.Global.gameState.inventoryState.itemsById.get(itemId);
      final lootDef = Loot.getDef(lootInst.type);
      final width = bounds[1] - bounds[0];
      final height = bounds[3] - bounds[2];
      final screenCx = (bounds[0] + width / 2) * cellSize * Hud.rScale;
      final screenCy = (bounds[2] + height / 2) * cellSize * Hud.rScale;
      // translate position to inventory position
      final invCx = screenCx + INVENTORY_RECT.x;
      final invCy = screenCy + INVENTORY_RECT.y;

      Main.Global.uiSpriteBatch.emitSprite(
          invCx,
          invCy,
          lootDef.spriteKey,
          (p) -> {
            p.sortOrder = 1;
            final b = p;
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
          (cx - width / 2) * cellSize * Hud.rScale, 
          (cy - height / 2) * cellSize * Hud.rScale,
          'ui/square_white',
          (p) -> {
            p.sortOrder = 2;

            final b = p;
            b.scaleX = width * cellSize * Hud.rScale;
            b.scaleY = height * cellSize * Hud.rScale;
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
    if (hasPickedUp()) {
      final lootInst = state.pickedUpInstance;
      final lootDef = Loot.getDef(lootInst.type);
      final spriteData = SpriteBatchSystem.getSpriteData(
          Main.Global.uiSpriteBatch.batchManager.spriteSheetData,
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

            final b = p;
            b.scale = Hud.rScale;
          });
    }

    // render hovered inventory ability slot
    final nearestAbilitySlot = state.nearestAbilitySlot;
    if (nearestAbilitySlot.slotDefinition != null
        && hasPickedUp()) {
      final lootInst = state.pickedUpInstance;
      final lootDef = Loot.getDef(lootInst.type);
      final canEquip = lootDef.category == 
        nearestAbilitySlot.slotDefinition.allowedCategory ||
        !hasPickedUp();
      final slotDef = nearestAbilitySlot.slotDefinition;

      Main.Global.uiSpriteBatch.emitSprite(
          slotDef.x, 
          slotDef.y,
          'ui/square_white',
          null,
          (p) -> {
            p.sortOrder = 3;
            final b = p;
            b.scaleX = slotDef.width;
            b.scaleY = slotDef.height;
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
    }
  }
}

class Hud {
  public static final HUD_LAYOUT_FILE = 'editor-data/hud.eds';
  public static var rScale = 4;
  static var aiNameText: h2d.Text;
  static var aiHealthBar: h2d.Graphics;
  static final aiHealthBarWidth = 200;
  static var hoveredEntityId: Entity.EntityId;
  static var tooltipTf: h2d.Text;
  static var questDisplay: h2d.Text;
  static var inactiveAbilitiesSb: SpriteBatchSystem;
  static var inactiveAbilitiesCooldownGraphics: h2d.Graphics;

  public static function init() {
    aiHealthBar = new h2d.Graphics(
        Main.Global.uiRoot);
    final font = Fonts.primary();
    aiNameText = new h2d.Text(
        font, 
        Main.Global.uiRoot);
    aiNameText.textAlign = Center;
    aiNameText.textColor = Game.Colors.pureWhite;

    questDisplay = new h2d.Text(
        Fonts.primary(),
        Main.Global.uiRoot);

    inactiveAbilitiesSb = new SpriteBatchSystem(
        Main.Global.inactiveAbilitiesRoot,
        hxd.Res.sprite_sheet_png,
        hxd.Res.sprite_sheet_json);
    inactiveAbilitiesCooldownGraphics = new h2d.Graphics(
        Main.Global.uiRoot);
  }

  public static function update(dt: Float) {
    questDisplay.text = '';
    aiNameText.text = '';
    aiHealthBar.clear();
    Main.Global.worldMouse.hoverState = 
      Main.HoverState.None;

    final uiState = Main.Global.uiState;
    final enabled = !uiState.passiveSkillTree.enabled
      && !uiState.mainMenu.enabled;
    uiState.hud.enabled = enabled;

    if (!enabled) {
      return;
    }

    aiNameText.x = Main.Global.uiRoot.width / 2;
    aiNameText.y = 10;
    aiHealthBar.x = aiNameText.x - aiHealthBarWidth / 2;
    aiHealthBar.y = 35;

    final x = Main.Global.rootScene.mouseX;
    final y = Main.Global.rootScene.mouseY;
    final threshold = 16;
    final hoveredMatch = Lambda.fold(
        Grid.getItemsInRect(
          Main.Global.dynamicWorldGrid,
          x, y, threshold, threshold),
        (entityId, result: {
          previousDist: Float,
          matchId: Entity.EntityId
        }) -> {
          final entRef = Entity.getById(entityId);
          final p = new h2d.col.Point(x, y);
          final c = new h2d.col.Circle(
              entRef.x, entRef.y, entRef.radius + threshold / 2);
          final distFromMouse = Utils.distance(
              x, y, entRef.x, entRef.y);
          final isMatch = distFromMouse < result.previousDist 
            && c.contains(p) 
            && switch(entRef.type) {
              case 
                  'ENEMY' 
                | 'INTERACTABLE_PROP'
                | 'LOOT':
                true;

              default: false;
            };

          if (isMatch) {
            return {
              previousDist: distFromMouse,
              matchId: entityId
            };
          }

          return result;
        }, {
          previousDist: Math.POSITIVE_INFINITY,
          matchId: Entity.NULL_ENTITY.id
        });
    Main.Global.hoveredEntity.id = hoveredMatch.matchId;
    InventoryDragAndDropPrototype.update(dt);
    Inventory.update(dt);
    Tooltip.update(dt);
    UiGrid.update(dt);
  }

  public static function render(time: Float) {
    Tooltip.render(time);
    InventoryDragAndDropPrototype.render(time);
    Inventory.render(time);
    Hud.UiGrid.render(time);

    if (!Main.Global.uiState.hud.enabled) {
      return;
    }

    // show hovered ai info
    {
      final healthBarHeight = 30;
      final hoveredEntityId = Main.Global.hoveredEntity.id;
      final entRef = Entity.getById(
          hoveredEntityId);
      if (entRef.type == 'ENEMY') {
        aiNameText.text = Entity.getComponent(entRef, 'aiType');
        final healthPctRemain = entRef.stats.currentHealth / 
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
      } 
    }

    // render quest statuses
    {
      if (!Main.Global.uiState.inventory.enabled) {
        final maxWidth = 300;
        questDisplay.text = Quest.format(
            Main.Global.gameState.questState);
        questDisplay.maxWidth = maxWidth;
        final win = hxd.Window.getInstance();

        final borderSprite = Main.Global.uiSpriteBatch.emitSprite(
            Main.nativePixelResolution.x - 10 - maxWidth,
            400,
            'ui/stylized_border_1');
        borderSprite.sortOrder = 0;
        borderSprite.scale = Hud.rScale;

        questDisplay.x = borderSprite.x;
        questDisplay.y = borderSprite.y + 15;
      }
    }

    var ps = Entity.getById('PLAYER').stats;

    if (ps == null) {
      return;
    }

    // render equipped abilities
    {
      final spriteEffect = (p) -> {
        p.scaleX = rScale * 1.0;
        p.scaleY = rScale * 1.0;
      };
      final inventoryEquippedSlots = InventoryDragAndDropPrototype
          .getEquippedAbilities();

      inactiveAbilitiesCooldownGraphics.clear();

      final hudAbilitySlotLayerId = 'layer_1';
      final editorState = UiGrid.loadHudLayout();
      final grid = editorState.gridByLayerId.get(hudAbilitySlotLayerId);
      final slotIds = [
        for (objectId => bounds in grid.itemCache) {
          final type = editorState.itemTypeById.get(objectId);

          if (type == 'hud_ability_slot') {
            {
              id: objectId,
              bounds: bounds
            };
          }
        }
      ];

      slotIds.sort(function byXPos(a, b) {
        final xA = a.bounds[0];
        final xB = b.bounds[0];

        return switch ([xA, xB]) {
          case xA < xB => true: -1;
          case xA > xB => true: 1;
          default: 0;
        }
      });
      
      // render hud equipped abilities
      for (slotIndex in 0...slotIds.length) {
        final slotInfo = slotIds[slotIndex];
        final type = editorState.itemTypeById.get(slotInfo.id);

        final lootId = inventoryEquippedSlots[slotIndex];

        if (lootId == null) {
          continue;
        }

        final cx = (slotInfo.bounds[0]) * Hud.rScale;
        final cy = (slotInfo.bounds[2]) * Hud.rScale;
        final lootInst = InventoryDragAndDropPrototype
          .getItemById(lootId); 
        final lootDef = Loot.getDef(lootInst.type);
        final playerRef = Entity.getById('PLAYER');
        final cooldownLeft = Cooldown.get(
            playerRef.cds,
            'ability__${lootInst.type}');
        final isCoolingDown = cooldownLeft > 0;

        if (isCoolingDown) {
          // draw pie chart for cooldown
          {
            final angleStart = 0 + 3 * Math.PI / 2;
            final progress = 1 - (cooldownLeft / lootDef.cooldown);
            final angleLength = Math.PI * 2 * progress;
            final g = inactiveAbilitiesCooldownGraphics;

            g.beginFill(0xfffffff, 0.6);
            g.drawPie(
                cx,
                cy,
                30,
                angleStart,
                angleLength);
          }

          final ref = inactiveAbilitiesSb.emitSprite(
              cx, cy,
              lootDef.spriteKey,
              null,
              spriteEffect);
          ref.sortOrder = 1;
        } else {
          final ref = Main.Global.uiSpriteBatch.emitSprite(
              cx, cy,
              lootDef.spriteKey,
              null,
              spriteEffect);
          ref.sortOrder = 1; 
        }
      }
    }
  }
}
