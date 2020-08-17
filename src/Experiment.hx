class Experiment {
  public static function init() {
    final EMPTY_HOVERED_NODE = {
      x: 0,
      y: 0,
      w: 0,
      h: 0
    };
    final s2d = Main.Global.staticScene;
    final state = {
      hoveredNodeBounds: EMPTY_HOVERED_NODE,
    };

    // render background
    function renderBackground(time: Float) {
      final ref = Main.Global.sb.emitSprite(
          -240,
          -135,
          'ui/square_white');
      final elem = ref.batchElement;
      ref.sortOrder = 0;
      elem.scaleX = 480;
      elem.scaleY = 270;
      elem.r = 0.2;
      elem.g = 0.2;
      elem.b = 0.2;

      return true;
    }
    Main.Global.renderHooks.push(renderBackground);

    final sessionRef = Session.create();

    // test passive skill tree
    {
      final passiveTreeLayoutFile = 
        'editor-data/passive_skill_tree.eds';

      function loadPassiveSkillTree(
          layoutData: Editor.EditorState) {
        final layersToIgnore = [
          'layer_prefab',
          'layer_marquee_selection'
        ];
        final orderedLayers = Lambda.filter(
            layoutData.layerOrderById,
            (layerId) -> {
              return !Lambda.exists(
                  layersToIgnore, 
                  (l) -> l == layerId);
            });

        function processTree(eachObject) {
          for (layerIndex in 0...orderedLayers.length) {
            final layerId = orderedLayers[layerIndex];
            final grid = layoutData.gridByLayerId.get(layerId);

            for (itemId => bounds in grid.itemCache) {
              final objectType = layoutData.itemTypeById.get(itemId);
              final objectMeta = Editor.getConfig(passiveTreeLayoutFile)
                .objectMetaByType
                .get(objectType);
              final x = bounds[0];
              final y = bounds[2];

              eachObject(x, y, itemId, objectType, objectMeta, layerIndex);
            }
          }
        }

        final renderScale = 4;
        final treeScene = Main.Global.uiRoot;
        final NULL_HOVERED_NODE = {
          nodeId: 'NO_HOVERED_NODE',
          startedAt: -1.
        } ;
        final state = {
          hoveredNode: NULL_HOVERED_NODE
        };
        final colRect = new h2d.col.Bounds();

        function isHoveredNode(
            x, y, width, height, point) {
          colRect.set(
              x, y, width, height); 

          return colRect.contains(point);
        }

        final hoverEasing = Easing.easeOutElastic;

        Main.Global.renderHooks.push(function renderTree(time: Float) {
          function runHoverAnimation(
              batchElement: h2d.SpriteBatch.BatchElement) {
            final duration = 0.2;
            final aliveTime = Main.Global.time 
              - state.hoveredNode.startedAt;
            final progress = Math.min(1, aliveTime / duration);
            final v = hoverEasing(progress);
            batchElement.scale = Utils.clamp(
                renderScale * v, 
                renderScale * 0.8, 
                renderScale * 1.2);
          }

          processTree((
                x, y, itemId, objectType, objectMeta, layerIndex) -> {
            final sx = x * renderScale;
            final sy = y * renderScale;
            final isHoveredNode = 
              state.hoveredNode.nodeId == itemId;
            // render node base
            {
              final spriteRef = Main.Global.uiSpriteBatch.emitSprite(
                  sx,
                  sy,
                  objectMeta.spriteKey);
              final b = spriteRef.batchElement;

              spriteRef.sortOrder = layerIndex;

              // run hover animation
              if (isHoveredNode) {
                runHoverAnimation(b);
              } else {
                b.scale = renderScale;
              }

              if (objectMeta.flipX) {
                b.scaleX *= -1;
              }

              if (objectMeta.flipY) {
                b.scaleY *= -1;
              }
            }

            // render node selection state
            final isSelected = Utils.withDefault(
                sessionRef.passiveSkillTreeState
                .nodeSelectionStateById.get(itemId),
                false);
            if (isSelected) {
              final spriteRef = Main.Global.uiSpriteBatch.emitSprite(
                  sx,
                  sy,
                  '${objectMeta.spriteKey}_selected_state');

              final b = spriteRef.batchElement;

              if (isHoveredNode) {
                runHoverAnimation(b);
              } else {
                b.scale = renderScale;
              }
            }

            return;
          });

          return true;
        });

        function handleTreeInteraction(dt: Float) {
          var nextHoveredNode = NULL_HOVERED_NODE;

          processTree((
                x, y, itemId, objectType, objectMeta, layerIndex) -> {

            final sx = x * renderScale;
            final sy = y * renderScale;
            final spriteData = SpriteBatchSystem.getSpriteData(
                Main.Global.uiSpriteBatch.batchManager.spriteSheetData,
                objectMeta.spriteKey);
            final w = spriteData.sourceSize.w * renderScale;
            final h = spriteData.sourceSize.h * renderScale;
            final isSkillNode = objectType.indexOf(
                'passive_skill_tree__node') != -1;
            final mx = treeScene.mouseX;
            final my = treeScene.mouseY;
            final cursorPoint = new h2d.col.Point(mx, my);
            final isHovered = isSkillNode
              ? isHoveredNode(
                sx - w/2, 
                sy - h/2, 
                w,
                h,
                cursorPoint)
              : false;

            if (isHovered) {
              final alreadyHovered = state.hoveredNode.nodeId == itemId;

              if (!alreadyHovered) {
                nextHoveredNode = {
                  nodeId: itemId,
                  startedAt: Main.Global.time
                };
              } else {
                nextHoveredNode = state.hoveredNode;
              } 
            }
          });

          state.hoveredNode = nextHoveredNode; 

          final isNodeSelectable = true;
          if (Main.Global.worldMouse.clicked
              && isNodeSelectable) {
            Session.logAndProcessEvent(sessionRef, {
              type: 'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION',
              data: {
                nodeId: state.hoveredNode.nodeId
              }
            });
          }

          Main.Global.logData.treeHoveredNode = state.hoveredNode;
          return true;
        }
        Main.Global.updateHooks.push(handleTreeInteraction);

      }

      SaveState.load(
          passiveTreeLayoutFile,
          false,
          null,
          loadPassiveSkillTree,
          (err) -> {
            trace('error loading passive tree');
          });  
    }

    final testSessionApis = false;
    if (testSessionApis) {
      final sessionRef = Session.create();
      final testFile = './temp/session_${sessionRef.sessionId}.txt';

      Main.Global.updateHooks.push((dt) -> {
        if (Main.Global.worldMouse.clicked) {
          final event = {
            type: 'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION',
            data: {
              nodeId: Utils.uid()
            }
          };
          Session.logEvent(testFile, event);
          Session.processEvent(sessionRef, event);
          Session.saveGame(
              sessionRef,
              (_) -> {
                trace('save game success');

                Session.loadGame(
                    sessionRef.gameId,
                    (gameData) -> {
                      trace('load game success', gameData);
                    },
                    (err) -> {
                      trace('load game error', err);
                    });
              },
              (err) -> {
                trace('save game error', err);
              });
        }

        return true;
      });
    }

    return () -> {};
  }
}
