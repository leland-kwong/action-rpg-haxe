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
      elem.r = 0.3;
      elem.g = 0.3;
      elem.b = 0.3;

      return true;
    }
    Main.Global.renderHooks.push(renderBackground);

    // passive tree stuff
    {
      final sb = new SpriteBatchSystem(
          s2d,
          hxd.Res.ui_passive_tree_png,
          hxd.Res.ui_passive_tree_json);
      final treeNodeSlices: Array<{
        name: String,
        data: String,
        keys: Array<{
          frame: Int,
          bounds: {
            x: Int,
            y: Int,
            w: Int,
            h: Int
          }
        }>
      }> = sb.batchManager.spriteSheetData.meta.slices;

      // setup node interactions
      for (slice in treeNodeSlices) {
        final firstFrame = slice.keys[0];
        final bounds = firstFrame.bounds;
        final i = new h2d.Interactive(
            bounds.w,
            bounds.h,
            s2d);
        i.x = bounds.x;
        i.y = bounds.y;

        i.onOver = (e: hxd.Event) -> {
          state.hoveredNodeBounds = bounds;
        };

        i.onOut = (e: hxd.Event) -> {
          state.hoveredNodeBounds = EMPTY_HOVERED_NODE;
        };
      } 


      function renderNodeLinks(time: Float) {

      }

      function renderTreeNodes(time: Float) {
        {
          final spriteData = SpriteBatchSystem.getSpriteData(
              sb, 'node_tree');
          final sourceSize = spriteData.spriteSourceSize;
          sb.emitSprite(
              0 + sourceSize.x, 
              0 + sourceSize.y,
              'node_tree');
        }

        final hoveredNodeBounds = state.hoveredNodeBounds;
        if (hoveredNodeBounds != EMPTY_HOVERED_NODE) {
          final spriteData = SpriteBatchSystem.getSpriteData(
              sb, 'node_tree');
          final sourceSize = spriteData.spriteSourceSize;

          sb.emitSprite(
              hoveredNodeBounds.x,
              hoveredNodeBounds.y,
              'node_state_hover');
        }

        return true;
      }
      Main.Global.renderHooks.push(renderTreeNodes);

    }

    Main.Global.updateHooks.push((dt) -> {
      if (Main.Global.worldMouse.clicked) {
      }

      return true;
    });

    return () -> {};
  }
}
