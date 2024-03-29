import h2d.Text;

typedef GuiControl = {
  x: Int,
  y: Int,
  width: Int,
  height: Int,
  // metadata about the control
  value: Dynamic,
  label: String
}

typedef GuiNodeList = Array<GuiNode>;

class GuiNode extends h2d.Interactive {
  public final state: Dynamic = {
    value: null,
    disabled: false
  };
}

typedef DialogInstanceId = String;

typedef DialogChoice = {
  text: String,
  action: {
    type: Session.EventType,
    data: Session.EventDetail
  }
}

typedef Dialog = () -> {
  characterName: String,
  text: String,
  ?choices: Array<DialogChoice>
};

class DialogBox {
  public static var instancesById 
    = new Map<String, h2d.Object>();

  public static function create(
      worldX: Float, 
      worldY: Float, 
      calcNextDialog: Dialog,
      id: DialogInstanceId) {

#if debugMode 
    if (instancesById.exists(id)) {
      throw new haxe.Exception(
          'dialog instance with id `${id}` already exists');
    }
#end
    final dialog = calcNextDialog();
    final padding = 10;
    final maxWidth = 400;
    final parent = new h2d.Object(Main.Global.scene.uiRoot);
    final getPos = () ->  Camera.toScreenPos(
        Main.Global.mainCamera, 
        worldX, 
        worldY);
    final fullScreenCloseButton = {
      final pos = getPos();
      final i = new h2d.Interactive(
        0, 0, parent);
      i.cursor = hxd.Cursor.Default;

      Main.Global.hooks.update.push(function autoResize(dt) {
        final res = Main.nativePixelResolution;
        // readjust position to be 0,0 at screen coords
        i.x = -parent.x;
        i.y = -parent.y;
        i.width = res.x;
        i.height = res.y;

        return parent.parent != null;
      });

      i.onClick = (e) -> {
        Hud.UiStateManager.send({
          type: 'UI_CLEAR_ALL'
        });
      }
      i;
    }

    instancesById.set(id, parent);

    Main.Global.hooks.update.push((dt) -> {
      final bounds = parent.getBounds(parent);
      final pos = getPos();
      parent.x = pos[0];
      parent.y = pos[1] - 5 - padding - bounds.height;

      final globalEnabled = Main.Global.uiState.dialogBox.enabled;
      if (!globalEnabled) {
        destroy(id);
        return false;
      }

      return parent.parent != null;
    });

    // character name display
    final ctf = {
      final tf = new h2d.Text(Fonts.primary(), parent);
      tf.text = dialog.characterName + '\n';
      tf.textColor = 0xffffff;
      tf.x = 0;
      tf.y = 0;
      tf.textAlign = Center;
      tf.maxWidth = maxWidth; 
      tf;
    }

    // dialog text
    final dtf = {
      final tf = new h2d.Text(Fonts.primary(), parent);

      parent.addChild(tf);
      tf.text = dialog.text + '\n';
      tf.textColor = 0xffffff;
      tf.x = 0;
      tf.y = ctf.textHeight + 10;
      tf.maxWidth = maxWidth; 
      tf;
    }

    // dialog interactive choices
    final choices = dialog.choices;
    if (choices != null) {
      var offsetY = dtf.y + dtf.textHeight;

      for (i in 0...choices.length) {
        final choice = choices[i];
        final tf = new h2d.Text(Fonts.primary(), parent);
        final alpha = 0.8;
        final textColor = 0xffffff;

        parent.addChild(tf);
        tf.text = '> ${choice.text}';
        tf.textColor = textColor;
        tf.x = dtf.x;
        tf.y = offsetY;
        tf.alpha = alpha;

        offsetY += tf.textHeight;

        final interact = new h2d.Interactive(
            tf.textWidth,
            tf.textHeight,
            parent);
        parent.addChild(interact);
        interact.x = tf.x;
        interact.y = tf.y; 
        tf.maxWidth = maxWidth; 

        interact.onClick = (e) -> {
          Main.Global.logData.dialogChoice = choice.action;
          Session.logAndProcessEvent(
              Main.Global.gameState,
              Session.makeEvent(
                choice.action.type,
                choice.action.data));

          destroy(id);
          // recreate instance
          // so that we can get the latest
          // dialog
          create(
              worldX, worldY, calcNextDialog, id);
        }

        interact.onOver = (e) -> {
          tf.alpha = 1;
          tf.textColor = 0xffff00;
        }

        interact.onOut = (e) -> {
          tf.alpha = alpha;
          tf.textColor = textColor;
        }
      }
    }

    final bounds = parent.getBounds(parent);
    final background = new h2d.Graphics();
    parent.addChildAt(background, 0);
    background.beginFill(0x000000);
    background.drawRect(
        -padding,
        -padding,
        maxWidth + padding * 2,
        bounds.height + padding * 2);

    // // character name background
    background.beginFill(0x003366);
    background.drawRect(
        -padding,
        -padding,
        maxWidth + padding * 2,
        ctf.textHeight);

    return id;
  }

  public static function destroy(
      id: DialogInstanceId) {
    if (!instancesById.exists(id)) {
      return;
    }

    instancesById.get(id)
      .remove();
    instancesById.remove(id);
  }
}

class GuiComponents {
  static final sortOrders = {
    mainMenuBg: 1000,
    menuItemHighlightBg: 1001,
  };

  public static function savedGameSlots(
      fetchGamesList) {
    final font = Fonts.primary();
    final itemPadding = 10;
    final itemSpacing = 50;
    final itemWidth = 500;
    final descenderHeight = 4;
    final state = {
      isAlive: true
    };
    final win = hxd.Window.getInstance();
    final root = new h2d.Object(Main.Global.scene.uiRoot);
    var gameSlotNodes: GuiNodeList = null;
    var gameDeleteNodes: GuiNodeList = null;

    function cleanup() {
      state.isAlive = false;
      root.remove();
    }

    function createGameSlotNodes(options) {
      return Lambda.map(
        options,
        (opt) -> {
          final interact = new GuiNode(
              opt.width,
              opt.height,
              root);

          interact.x = opt.x;
          interact.y = opt.y;
          interact.state.value = opt.value;
          interact.onClick = (e) -> {
            Hud.UiStateManager.send({
              type: 'START_GAME',
              data: opt.value
            });

            cleanup();
          };

          final tf = new h2d.Text(
              font,
              interact);

          tf.text = opt.label;
          tf.x = itemPadding / 2;
          tf.y = itemPadding / 2;

          return interact;
        });
    }

    function createGameDeleteNodes(
        refreshInteractNodes) { 
      return Lambda.map(
          gameSlotNodes,
          (related: GuiNode) -> {
            final relatedValue: Session.SessionRef = 
              related.state.value; 

            if (Session.isEmptyGameState(relatedValue)) {
              return new GuiNode(0, 0);
            }
            
            final isCurrentlyActiveGame = relatedValue.gameId ==
              Main.Global.gameState.gameId;
            final text = isCurrentlyActiveGame
              ? 'currently active game'
              : 'delete';
            final textWidth = Gui.calcTextWidth(
                Fonts.primary(), text);
            final textHeight = Gui.calcTextHeight(
                Fonts.primary(), text);
            final interact = new GuiNode(
                textWidth + itemPadding,
                textHeight + itemPadding + descenderHeight,
                root);

            final tf = new h2d.Text(
                font,
                interact);

            tf.text = text;
            tf.x = itemPadding / 2;
            tf.y = itemPadding / 2;
            tf.alpha = isCurrentlyActiveGame 
              ? 0.7
              : 0.8;

            interact.x = related.x + related.width;
            interact.y = related.y;
            interact.state.disabled = isCurrentlyActiveGame;

            if (!isCurrentlyActiveGame) {
              interact.onClick = (e) -> {
                Hud.UiStateManager.send({
                  type: 'DELETE_GAME',
                  data: related.state.value.gameId
                }, (_, err) -> {
                  if (err != null) {
                    HaxeUtils.handleError('delete game failure')(err);
                    return;
                  }

                  refreshInteractNodes();
                });
              };
            }

            return interact;
          });
    }

    function refreshInteractNodes() {
      function removeGuiNodes(
          nodeList: GuiNodeList) {
        if (nodeList == null) {
          return;
        }

        for (node in nodeList) {
          node.remove();
        }
      }

      removeGuiNodes(gameSlotNodes);
      removeGuiNodes(gameDeleteNodes);
      
      function onGamesFetched(gamesList: Array<Session.SessionRef>) {
        final options: Array<GuiControl> = Lambda.mapi(
            gamesList,
            (index, gameState) -> {
              final label = Session.isEmptyGameState(gameState) 
                ? 'new game' 
                : [
                'gameId: ${gameState.gameId}',
                'lastUpdated: ${gameState.lastUpdatedAt}'
                ].join('\n');
              final textHeight = Std.int(
                  Gui.calcTextHeight(Fonts.primary(), label));

              return {
                value: gameState,
                label: label,
                x: 400,
                y: index * (20 * 2 + itemSpacing) + 500,
                width: itemWidth + itemPadding,
                height: textHeight
                  + itemPadding 
                  + descenderHeight
              };
            });
        gameSlotNodes = createGameSlotNodes(options);
        gameDeleteNodes = createGameDeleteNodes(
            refreshInteractNodes);
      }
      fetchGamesList(onGamesFetched);
    }

    refreshInteractNodes();

    Main.Global.hooks.render.push((time) -> {
      final hoveredGameSlot = Lambda.find(
          gameSlotNodes,
          (i) -> i.isOver());
      final hoveredDeleteNode = Lambda.find(
          gameDeleteNodes,
          (i) -> i.isOver());
      final hoveredNode = hoveredGameSlot != null 
        ? hoveredGameSlot 
        : hoveredDeleteNode;

      if (hoveredNode != null && !hoveredNode.state.disabled) { 
        Main.Global.uiSpriteBatch.emitSprite(
            hoveredNode.x,
            hoveredNode.y,
            'ui/square_white',
            null,
            (p) -> {
              p.sortOrder = GuiComponents
                .sortOrders
                .menuItemHighlightBg;
              p.alpha = 0.8;
              p.r = 0.9;
              p.g = 0;
              p.b = 0.5;
              p.scaleX = hoveredNode.width;
              p.scaleY = hoveredNode.height;
            });
      }
      
      return state.isAlive;
    });

    return cleanup;
  }

  public static function mainMenuOptions(
      options: Array<Array<String>>) {
    final font = Fonts.primary();
    final itemPadding = 10;
    final itemSpacing = 10;
    final itemWidth = 200;
    final descenderHeight = 4;
    final state = {
      isAlive: true
    };
    final win = hxd.Window.getInstance();
    final options: Array<GuiControl> = Lambda.mapi(
        options, 
        (index, option) -> {
          return {
            value: option[0],
            label: option[1],
            x: 0,
            y: index * (20 + itemSpacing) + 500,
            width: itemWidth + itemPadding,
            height: 20 + itemPadding + descenderHeight
          };
    });

    final textFields = Lambda.map(
        options, 
        (o) -> {
          final tf = new h2d.Text(
              font,
              Main.Global.scene.uiRoot);

          return tf;
        });

    function cleanup() {
      state.isAlive = false;

      for (tf in textFields) {
        tf.remove();
      }
    }

    Main.Global.hooks.input.push((dt) -> {
      Main.Global.worldMouse.hoverState = Main.HoverState.Ui;

      final mx = Main.Global.scene.uiRoot.mouseX;
      final my = Main.Global.scene.uiRoot.mouseY;
      final hoveredItem = Gui.getHoveredControl(
          options, mx, my);

      if (hoveredItem != null && Main.Global.worldMouse.clicked) { 
        Hud.UiStateManager.send({
          type: 'SWITCH_SCENE',
          data: hoveredItem.value
        });

        cleanup();
        return false;
      }

      // update main menu option text nodes
      {
        for (o in options) {
          o.x = 100;
        }

        for (i in 0...textFields.length) {
          final tf = textFields[i];
          final o = options[i];

          tf.text = o.label;
          tf.x = o.x + itemPadding / 2;
          tf.y = o.y + itemPadding / 2;
        }
      }

      return state.isAlive;
    });

    Main.Global.hooks.render.push((time) -> {
      final mx = Main.Global.scene.uiRoot.mouseX;
      final my = Main.Global.scene.uiRoot.mouseY;
      final hoveredItem = Gui.getHoveredControl(
          options, mx, my);

      // render screen overlay
      Main.Global.uiSpriteBatch.emitSprite(
          0,
          0,
          'ui/square_white',
          null,
          (p) -> {
            p.sortOrder = GuiComponents.sortOrders.mainMenuBg;
            p.alpha = 0.8;
            p.r = 0;
            p.g = 0;
            p.b = 0;
            p.scaleX = win.width;
            p.scaleY = win.height;
          });

      // render hovered item bg
      if (hoveredItem != null) { 
        Main.Global.uiSpriteBatch.emitSprite(
            hoveredItem.x,
            hoveredItem.y,
            'ui/square_white',
            null,
            (p) -> {
              p.sortOrder = GuiComponents
                .sortOrders
                .menuItemHighlightBg;
              p.alpha = 0.8;
              p.r = 0.9;
              p.g = 0;
              p.b = 0.5;
              p.scaleX = hoveredItem.width;
              p.scaleY = hoveredItem.height;
            });
      }
      
      return state.isAlive;
    });

    return cleanup;
  }

  public static function mainMenu() {
    final state = {
      isAlive: false
    };

    function openGamesList() {
      function fetchGamesList(onComplete) {
        final gamesList = Session.getGamesList();
        final gameRefsList = [];
        final asyncCallbacks = Lambda.map(
            gamesList,
            (gameId) -> {
              return (_onSuccess, _onError) -> {
                final isCurrentGame = Main.Global.gameState.gameId == gameId;

                if (isCurrentGame) {
                  _onSuccess(Main.Global.gameState);
                  return;
                }

                Session.loadMostRecentGameFile(
                    gameId,
                    _onSuccess,
                    _onError);
              };
            });
        function placeholderSlotCallback(_onSuccess, _) {
          _onSuccess('PLACEHOLDER_CALLBACK');
        }

        Utils.asyncParallel(
            asyncCallbacks.length > 0
            ? asyncCallbacks
            : [placeholderSlotCallback], 
            (gameRefs: Array<Dynamic>) -> {
              final numSlots = 3;
              final gameSlots = [
                // setup empty slots first
                for (i in 0...numSlots) 
                  Session.createGameState(i)
              ];

              // fill empty slots with previous game refs
              for (ref in gameRefs) {
                if (ref != 'PLACEHOLDER_CALLBACK') {
                  gameSlots[ref.slotId] = ref;
                }
              } 

              onComplete(gameSlots);
            }, 
            HaxeUtils.handleError('error loading game files'));
      }

      final cleanup = GuiComponents.savedGameSlots(fetchGamesList);
      Main.Global.hooks.update.push((dt) -> {
        if (!state.isAlive) {
          cleanup();
        }

        return state.isAlive;
      });
    }

    function openMenuOptions() {
      final options = [
        ['editor', 'Editor'],
        ['experiment', 'Experiment'],
        ['exit', 'Exit']
      ];

      final cleanup = GuiComponents.mainMenuOptions(options); 

      Main.Global.hooks.update.push((dt) -> {
        if (!state.isAlive) {
          cleanup();
        }

        return state.isAlive;
      });
    }

    Main.Global.hooks.update.push((dt) -> {
      final menuEnabled = Main.Global.uiState.mainMenu.enabled;
      final shouldOpen = menuEnabled
        && !state.isAlive;
      final shouldClose = !menuEnabled
        && state.isAlive;

      if (shouldOpen) {
        state.isAlive = true;
        openGamesList();
        openMenuOptions();
      }

      if (shouldClose) {
        state.isAlive = false;
      }

      return true;
    });
  }
}

class Gui {
  public static final margin = 10;

  static var tempTf: h2d.Text;

  public static function init() {
    final state = {
      isAlive: true
    };

    Main.Global.hooks.render.push((time) -> {
      tempTf.text = '';

      return state.isAlive;
    });

    return () -> {
      state.isAlive = false;
    };
  }

  public static function getHoveredControl(
      options: Array<GuiControl>,
      x, 
      y) {

    final colBounds = new h2d.col.Bounds();
    final p = new h2d.col.Point(x, y);
    final hoveredOption = (o) -> {
      colBounds.set(o.x, o.y, o.width, o.height); 

      return colBounds.contains(p);
    };

    return Lambda.find(
        options, 
        hoveredOption);
  }

  // useful for measuring text since it is
  // a singleton text node
  public static function tempText(
      font, 
      text) {

    if (tempTf == null) {
      tempTf = new h2d.Text(
          Fonts.primary(), 
          Main.Global.rootScene);
    }

    tempTf.font = font;
    tempTf.text = text;

    return tempTf; 
  }

  public static function calcTextHeight(font, text) {
    return tempText(font, text).textHeight;
  }

  public static function calcTextWidth(font, text) {
    return tempText(font, text).textWidth;
  }

  public static function tests() {
    final options = [
    {
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      value: 'foo',
      label: ''
    },
    {
      x: 0,
      y: 0,
      width: 20,
      height: 40,
      value: 'fooA',
      label: ''
    }
    ];

    TestUtils.assert('should have hovered item', (passed) -> {
      final hoveredItem = Gui.getHoveredControl(
          options,
          10,
          30);

      passed(hoveredItem.value == 'fooA');
    });

    TestUtils.assert('should not have hovered item', (passed) -> {
      final hoveredItem = Gui.getHoveredControl(
          options,
          30,
          10);

      passed(
          hoveredItem == null);
    });
  }
}

