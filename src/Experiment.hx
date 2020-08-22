class Experiment {
  public static function init() {
    final EMPTY_HOVERED_NODE = {
      x: 0,
      y: 0,
      w: 0,
      h: 0
    };
    final treeScene = Main.Global.uiRoot;
    final treeRootObj = new h2d.Object(treeScene);
    final NULL_HOVERED_NODE = {
      nodeId: 'NO_HOVERED_NODE',
      startedAt: -1.
    };

    final state = {
      hoveredNode: NULL_HOVERED_NODE,
      highlightedItem: null,
      invalidLinks: new Map<String, String>(),
      invalidNodes: new Map<String, String>(),
      shouldCleanup: false,

      translate: {
        x: 0,
        y: 0
      },

      dragState: {
        isDragStart: false,
        isDragging: false,
        isDragEnd: false,

        startPos: {
          x: 0,
          y: 0
        },

        delta: {
          x: 0,
          y: 0
        },

        originalTranslate: {
          x: 0,
          y: 0
        }
      },

      renderScale: 2
    };
    final sbs = Main.Global.uiSpriteBatch;
    final cleanupFns = [];

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
      elem.r = 0.1;
      elem.g = 0.1;
      elem.b = 0.1;

      return !state.shouldCleanup;
    }
    Main.Global.renderHooks.push(renderBackground);

    final sessionRef = Session.create();

    // test passive skill tree
    {
      final debugOptions = {
        renderTreeCollisions: false
      };
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

        final colRect = new h2d.col.Bounds();
        final treeCollisionGrid = Grid.create(4);

        function calcNumSelectedNodes(
            sessionRef: Session.SessionRef) {
          return Lambda.count(
              sessionRef
                .passiveSkillTreeState
                .nodeSelectionStateById,
              Utils.isTrue);
        }

        function calcNumUnusedPoints(sessionRef) {
          final pointsAvailable = sessionRef
            .passiveSkillTreeState
            .totalPointsAvailable;

          return pointsAvailable 
            - calcNumSelectedNodes(sessionRef);
        }

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

        function calcNumSelectedNodesAtLink(
            linkId) {
          var numSelectedNodes = 0;

          for (nodeId in linkNodeTouches.nodesByLinkId.get(linkId)) {
            if (isNodeSelected(sessionRef, nodeId)) {
              numSelectedNodes += 1;
            }
          }

          return numSelectedNodes;
        }

        function isSelectableNode(nodeId) {
          for (linkId in 
              linkNodeTouches.linksByNodeId.get(nodeId)) {
            if (calcNumSelectedNodesAtLink(linkId) > 0) {
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
          final selectedCount = calcNumSelectedNodes(sessionRef);
          final isOnlySelectedNode = connectedCount == 0 
            && selectedCount == 2; 

          return isOnlySelectedNode
            // subtract 1 because current node is still selected
            || connectedCount == selectedCount - 1;
        }

        function setSelectedColor(
            spriteRef: SpriteBatchSystem.SpriteRef) {
          spriteRef.batchElement.r = 0.4;
          spriteRef.batchElement.r = 0.5;
          spriteRef.batchElement.r = 0.6;
        }

        final pointCounterTf = {
          final tf = new h2d.Text(
              Fonts.primary(),
              treeRootObj);
          tf.textAlign = Center;
          tf.textColor = 0xffffff;

          Main.Global.updateHooks.push((dt) -> {
            final win = hxd.Window.getInstance();
            final numUnusedPoints = calcNumUnusedPoints(sessionRef);

            tf.x = win.width / 2;
            tf.y = 10;
            tf.text = 'unused skill points: ${numUnusedPoints}';

            return !state.shouldCleanup;
          });
        }
        final hoverEasing = Easing.easeOutElastic;

        Main.Global.renderHooks.push(function renderTree(time: Float) {
          final hasUnusedPoints = calcNumUnusedPoints(sessionRef) > 0;

          function runHoverAnimation(
              batchElement: h2d.SpriteBatch.BatchElement) {
            final duration = 0.2;
            final aliveTime = Main.Global.time 
              - state.hoveredNode.startedAt;
            final progress = Math.min(1, aliveTime / duration);
            final v = hoverEasing(progress);
            batchElement.scale = Utils.clamp(
                state.renderScale * v, 
                state.renderScale * 0.8, 
                state.renderScale * 1.2);
          }

          processTree((
                x, y, itemId, objectType, objectMeta, layerIndex) -> {
            final sx = x * state.renderScale 
              + state.translate.x * state.renderScale;
            final sy = y * state.renderScale 
              + state.translate.y * state.renderScale;
            final isHoveredNode = 
              state.hoveredNode.nodeId == itemId;
            // render object
            {
              final spriteRef = sbs.emitSprite(
                  sx,
                  sy,
                  objectMeta.spriteKey);
              final b = spriteRef.batchElement;

              spriteRef.sortOrder = layerIndex;

              // run hover animation for skill node
              if (isHoveredNode) {
                runHoverAnimation(b);
              } else {
                b.scale = state.renderScale;
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

              // handle link styling
              if (isLinkType(objectType)) {
                final numSelected = calcNumSelectedNodesAtLink(itemId);
                final isFullyLinked = numSelected > 1;
                final isLeadingToNewSelectable = 
                  (numSelected == 1 && hasUnusedPoints);

                if (isFullyLinked
                    || isLeadingToNewSelectable) {
                  setSelectedColor(spriteRef);
                } else {
                  b.r = 0.25;
                  b.g = 0.25;
                  b.b = 0.25;
                }
              }

              if (isSkillNode(objectType)) {
                // dim icon inactive icon
                if (!isNodeSelected(sessionRef, itemId)
                    && !isHoveredNode) {
                  b.r *= 0.7;
                  b.g *= 0.7;
                  b.b *= 0.7;
                }
              }
            }

            // render node selection state
            final isSelected = isSkillNode(objectType) 
              && Utils.withDefault(
                  sessionRef.passiveSkillTreeState
                  .nodeSelectionStateById.get(itemId),
                  false);
            final shouldHighlightNode = isSelected || 
                (isSkillNode(objectType) 
                && isSelectableNode(itemId)
                && hasUnusedPoints);

            if (shouldHighlightNode) {
              final nodeSize = Utils.withDefault(
                  objectMeta.data.size, 
                  1);
              final spriteRef = Main.Global.uiSpriteBatch.emitSprite(
                  sx,
                  sy,
                  'ui/passive_skill_tree__node_size_${nodeSize}_selected_state');

              final b = spriteRef.batchElement;

              if (isHoveredNode) {
                runHoverAnimation(b);
              } else {
                b.scale = state.renderScale;
              }

              if (isSelected) {
                setSelectedColor(spriteRef);
              } 

              // animation to indicate that node is selectable
              if (!isSelected) {
                b.alpha *= 0.5 + Math.sin(Main.Global.time * 4) * 0.5;
              }
            }

            return;
          });

          return !state.shouldCleanup;
        });

        function handleTreeInteraction(dt: Float) {
          final hasUnusedPoints = calcNumUnusedPoints(sessionRef) > 0;
          var isFirstLink = true;
          var nextHoveredNode = NULL_HOVERED_NODE;

          processTree((
                x, y, itemId, objectType, objectMeta, layerIndex) -> {

            final sx = (x + state.translate.x) * state.renderScale;
            final sy = (y + state.translate.y) * state.renderScale;
            final spriteData = SpriteBatchSystem.getSpriteData(
                Main.Global.uiSpriteBatch.batchManager.spriteSheetData,
                objectMeta.spriteKey);
            final w = spriteData.sourceSize.w * state.renderScale;
            final h = spriteData.sourceSize.h * state.renderScale;
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
          });

          state.hoveredNode = nextHoveredNode; 

          final isHoveredNodeSelected = 
            isNodeSelected(sessionRef, state.hoveredNode.nodeId);
          final isSelectionRequest = Main.Global.worldMouse.clicked
            && state.hoveredNode != NULL_HOVERED_NODE;
          if (isSelectionRequest) {
            if ((isSelectableNode(state.hoveredNode.nodeId)
                    && hasUnusedPoints
                    && !isHoveredNodeSelected)
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

          return !state.shouldCleanup;
        }
        Main.Global.updateHooks.push(handleTreeInteraction);

        function handleMouseEvents(e: hxd.Event) {
          final mx = Std.int(treeScene.mouseX);
          final my = Std.int(treeScene.mouseY);

          final isWheel = e.kind == hxd.Event.EventKind.EWheel;

          if (isWheel) {
            final currentZoom = state.renderScale;
            final nextZoom = Std.int(
                Utils.clamp(
                  currentZoom - Std.int(e.wheelDelta),
                  1,
                  4));
            final mouseDelta = {
              x: Std.int(mx / nextZoom
                - (mx / currentZoom)),
              y: Std.int(my / nextZoom
                - (my / currentZoom))
            }
            // translate so that it is zooming to cursor position
            final newTranslate = {
              x: state.translate.x + mouseDelta.x,
              y: state.translate.y + mouseDelta.y,
            };

            state.translate = newTranslate;
            state.renderScale = nextZoom;
          }

          // handle dragging
          {
            final isDragStart = e.kind == hxd.Event.EventKind.EPush;
            if (isDragStart) {
              state.dragState.startPos.x = mx;
              state.dragState.startPos.y = my;
              state.dragState.originalTranslate = state.translate;
              state.dragState.isDragStart = true;
              state.dragState.isDragging = true;
            }

            final isDragEnd = e.kind == hxd.Event.EventKind.ERelease;
            if (isDragEnd) {
              state.dragState.isDragEnd = true;
              state.dragState.isDragging = false;
            }
          }

          if (state.dragState.isDragging) {
            final ds = state.dragState;
            ds.delta = {
              x: Std.int((mx - ds.startPos.x) / state.renderScale),
              y: Std.int((my - ds.startPos.y) / state.renderScale)
            };
            state.translate = {
              x: ds.originalTranslate.x 
                + ds.delta.x,
              y: ds.originalTranslate.y 
                + ds.delta.y
            };
          }
        }
        treeScene.addEventListener(handleMouseEvents);
        cleanupFns.push(function cleanupEventListeners() {
          treeScene.removeEventListener(handleMouseEvents);
        });

        function renderTreeCollisions(time: Float) {
          for (itemId => bounds in treeCollisionGrid.itemCache) {
            final cellSize = treeCollisionGrid.cellSize;
            final x = bounds[0] * cellSize;
            final y = bounds[2] * cellSize;
            final w = (bounds[1] - bounds[0]) * cellSize;
            final h = (bounds[3] - bounds[2]) * cellSize;
            final ref = Main.Global.uiSpriteBatch.emitSprite(
                (x + state.translate.x) * state.renderScale,
                (y + state.translate.y) * state.renderScale,
                'ui/square_white');
            final b = ref.batchElement;

            ref.sortOrder = 100;
            b.scale = state.renderScale;
            b.scaleX *= w;
            b.scaleY *= h;
            b.alpha = 0.1;

            final objectType = layoutData.itemTypeById.get(itemId);

            if (isSkillNode(objectType)) {
              b.b = 0;
            }
          } 

          return !state.shouldCleanup;
        }

        if (debugOptions.renderTreeCollisions) {
          Main.Global.renderHooks.push(renderTreeCollisions);
        }

        Main.Global.updateHooks.push(function update(dt: Float) {
          Main.Global.logData.skillTreeState = {
            dragState: state.dragState,
            translate: state.translate,
            zoom: state.renderScale
          };

          if (state.shouldCleanup) {
            for (fn in cleanupFns) {
              fn();
            }
            treeRootObj.remove();
          }

          return !state.shouldCleanup;
        });
      }

      SaveState.load(
          passiveTreeLayoutFile,
          false,
          null,
          loadPassiveSkillTree,
          HaxeUtils.handleError(
            'error loading passive skill tree',
            (err) -> {
              hxd.System.exit();
            }));  
    }

    return () -> {
      state.shouldCleanup = true;
    };
  }
}
