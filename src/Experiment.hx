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

        final renderScale = 3;
        final treeScene = Main.Global.uiRoot;
        final NULL_HOVERED_NODE = {
          nodeId: 'NO_HOVERED_NODE',
          startedAt: -1.
        } ;
        final state = {
          hoveredNode: NULL_HOVERED_NODE,
          highlightedItem: null,
          invalidLinks: new Map<String, String>(),
          invalidNodes: new Map<String, String>()
        };
        final colRect = new h2d.col.Bounds();
        final treeCollisionGrid = Grid.create(4);

        function isNodeSelected(
            sessionRef: Session.SessionRef,
            nodeId) {

          return Utils.withDefault(
              sessionRef
              .passiveSkillTreeState
              .nodeSelectionStateById
              .get(nodeId),
              false);
        }

        function isSkillNode(objectType: String) {
          return objectType.indexOf(
              'passive_skill_tree__node') != -1;
        }

        function isLinkType(objectType: String) {
          return objectType
            .indexOf('passive_skill_tree__link') != -1;
        }

        // finds all links and nodes that are touching
        function getLinkNodeTouches(treeCollisionGrid) {
          processTree((
                x, y, itemId, objectType, objectMeta, layerIndex) -> {

            final spriteData = SpriteBatchSystem.getSpriteData(
                Main.Global.uiSpriteBatch.batchManager.spriteSheetData,
                objectMeta.spriteKey);
            final threshold = 2;
            final w = spriteData.sourceSize.w + threshold;
            final h = spriteData.sourceSize.h + threshold;
           
            Grid.setItemRect(
                treeCollisionGrid,
                x,
                y,
                w,
                h,
                itemId);  
          });

          final linksByNodeId = new Map<String, Array<String>>();
          final nodesByLinkId = new Map<String, Array<String>>();

          function gridFilterLink(itemId) {
            final objectType = layoutData.itemTypeById.get(itemId);

            return isLinkType(objectType);
          }

          function gridFilterNode(itemId) {
            final objectType = layoutData.itemTypeById.get(itemId);

            return isSkillNode(objectType) 
              || objectType == 'passive_skill_tree__root';
          }

          for (itemId => bounds in treeCollisionGrid.itemCache) {
            final cellSize = treeCollisionGrid.cellSize;
            final x = bounds[0] * cellSize;
            final y = bounds[2] * cellSize;
            final w = (bounds[1] - bounds[0]) * cellSize;
            final h = (bounds[3] - bounds[2]) * cellSize;

            final objectType = layoutData.itemTypeById.get(itemId);
            
            // nodes can touch more than one link
            if (isSkillNode(objectType) ||
                itemId == 'SKILL_TREE_ROOT') {
              final linksTouching = Grid.getItemsInRect(
                  treeCollisionGrid,
                  x + w / 2, 
                  y + h / 2,
                  w, 
                  h,
                  gridFilterLink);
              final list = []; 
              for (linkId in linksTouching) {
                list.push(linkId);
              }
              final isValidNode = list.length > 0;
              if (!isValidNode) {
                state.invalidNodes.set(itemId, itemId);
              }
              linksByNodeId.set(itemId, list);
            }

            if (isLinkType(objectType)) {
              final nodesTouching = Grid.getItemsInRect(
                  treeCollisionGrid,
                  x + w / 2, 
                  y + h / 2,
                  w, 
                  h,
                  gridFilterNode);
              final list = []; 
              for (nodeId in nodesTouching) {
                list.push(nodeId);
              }
              final isValidLink = list.length == 2;

              if (!isValidLink) {
                state.invalidLinks.set(itemId, itemId);
              }

              nodesByLinkId.set(itemId, list);
            }
          }

          return {
            linksByNodeId: linksByNodeId,
            nodesByLinkId: nodesByLinkId
          };
        }

        final linkNodeTouches = getLinkNodeTouches(
           treeCollisionGrid);

        function isHoveredNode(
            x, y, width, height, point) {
          colRect.set(
              x, y, width, height); 

          return colRect.contains(point);
        }

        function isLinkTouchingASelectedNode(
            linkId, 
            ignoreId = null) {
          for (nodeId in linkNodeTouches.nodesByLinkId.get(linkId)) {
            if (nodeId != ignoreId 
                && isNodeSelected(sessionRef, nodeId)) {
              return true;
            }
          }

          return false;
        }

        function isSelectableNode(nodeId) {
          for (linkId in 
              linkNodeTouches.linksByNodeId.get(nodeId)) {
            if (isLinkTouchingASelectedNode(linkId)) {
              return true;
            }
          }

          return false;
        }

        function traverseBranch(
            nodeId: String, 
            visitedList: Map<String, String>,
            predicate = null) {
          final links = linkNodeTouches.linksByNodeId.get(nodeId);

          if (links == null) {
            return visitedList;
          }

          for (linkId in links) {
            final nodesByLinkId = linkNodeTouches.nodesByLinkId;
            for (nodeId in nodesByLinkId.get(linkId)) {
              final shouldTraverse = predicate != null
                ? predicate(nodeId)
                : true;
              if (!visitedList.exists(nodeId) && shouldTraverse) {
                visitedList.set(nodeId, nodeId);
                traverseBranch(nodeId, visitedList, predicate);
              }
            }  
          }

          return visitedList;
        }

        function getFirstSelectedSiblingNode(sourceNodeId) {
          for (linkId in 
              linkNodeTouches.linksByNodeId.get(sourceNodeId)) {

            for (nodeId in 
                linkNodeTouches.nodesByLinkId.get(linkId)) {

              if (nodeId != sourceNodeId
                  && isNodeSelected(sessionRef, nodeId)) {
                return nodeId;
              }
            }
          }

          return null;
        }

        // traverse any sibling node's links and verify
        // that the number of connected nodes is 
        // the same as the number of selected nodes 
        // excluding the one to be deselected
        function isDeselectableNode(nodeIdToDeselect) {
          final selectedSiblingNode = getFirstSelectedSiblingNode(
              nodeIdToDeselect);

          final visitedList = traverseBranch(
              selectedSiblingNode, 
              new Map(),
              (nodeId) -> {
                return nodeId != nodeIdToDeselect
                  && isNodeSelected(sessionRef, nodeId);
              });

          final connectedCount = Lambda.count(
              visitedList);
          // selected count also includes the root node
          final selectedCount = Lambda.count(
              sessionRef.passiveSkillTreeState.nodeSelectionStateById,
              (selected) -> selected);
          final isOnlySelectedNode = connectedCount == 0 
            && selectedCount == 2; 

          return isOnlySelectedNode
            // subtract 1 because current node is still selected
            || connectedCount == selectedCount - 1;
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
            // render object
            {
              final spriteRef = Main.Global.uiSpriteBatch.emitSprite(
                  sx,
                  sy,
                  objectMeta.spriteKey);
              final b = spriteRef.batchElement;

              spriteRef.sortOrder = layerIndex;

              // run hover animation for skill node
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

              if (state.highlightedItem == itemId
                  || state.invalidLinks.exists(itemId)) {
                b.g = 0.4;
                b.b = 0;
              }

              // highlight link if touching a selected node
              if (isLinkType(objectType) 
                  && isLinkTouchingASelectedNode(itemId)) {
                b.b = 0;
              }
            }

            // render node selection state
            final isSelected = isSkillNode(objectType) 
              && Utils.withDefault(
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
          var isFirstLink = true;
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
            final mx = treeScene.mouseX;
            final my = treeScene.mouseY;
            final cursorPoint = new h2d.col.Point(mx, my);
            final isHovered = isSkillNode(objectType)
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

            // debug link connections
            if (isLinkType(objectType) && isFirstLink) {
              isFirstLink = false;

              final linkedNodes = Grid.getItemsInRect(
                  layoutData.gridByLayerId.get('layer_2'),
                  x - w / 2,
                  y - h / 2,
                  w,
                  h);

              for (nodeId in linkedNodes) {
                final objectType = layoutData.itemTypeById.get(nodeId);
                // Session.processEvent(
                //     sessionRef,
                //     {
                //       type: 'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION',
                //       data: { nodeId: nodeId }
                //     });
              }

              Main.Global.logData.treeLinkData = linkedNodes;
            }
          });

          state.hoveredNode = nextHoveredNode; 

          final isHoveredNodeSelected = 
            isNodeSelected(sessionRef, state.hoveredNode.nodeId);
          if (Main.Global.worldMouse.clicked
              && state.hoveredNode != NULL_HOVERED_NODE) {
            if ((!isHoveredNodeSelected 
                  && isSelectableNode(state.hoveredNode.nodeId))
                ||(isHoveredNodeSelected
                  && isDeselectableNode(state.hoveredNode.nodeId))) {
              Session.logAndProcessEvent(sessionRef, {
                type: 'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION',
                data: {
                  nodeId: state.hoveredNode.nodeId
                }
              });
            }
          }

          Main.Global.logData.treeHoveredNode = state.hoveredNode; 

          return true;
        }
        Main.Global.updateHooks.push(handleTreeInteraction);

        function renderTreeCollisions(time: Float) {
          for (itemId => bounds in treeCollisionGrid.itemCache) {
            final cellSize = treeCollisionGrid.cellSize;
            final x = bounds[0] * cellSize;
            final y = bounds[2] * cellSize;
            final w = (bounds[1] - bounds[0]) * cellSize;
            final h = (bounds[3] - bounds[2]) * cellSize;
            final ref = Main.Global.uiSpriteBatch.emitSprite(
                x * renderScale,
                y * renderScale,
                'ui/square_white');
            final b = ref.batchElement;

            ref.sortOrder = 100;
            b.scale = renderScale;
            b.scaleX *= w;
            b.scaleY *= h;
            b.alpha = 0.1;

            final objectType = layoutData.itemTypeById.get(itemId);

            if (isSkillNode(objectType)) {
              b.b = 0;
            }
          } 

          return true;
        }
        // Main.Global.renderHooks.push(renderTreeCollisions);
      }

      SaveState.load(
          passiveTreeLayoutFile,
          false,
          null,
          loadPassiveSkillTree,
          (err) -> {
            trace('error loading passive tree', err);
          });  
    }

    return () -> {};
  }
}
