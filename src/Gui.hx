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

class Gui {
  static var tempTf: h2d.Text;

  public static function init() {
    final state = {
      isAlive: true
    };

    tempTf = new h2d.Text(
        Main.Global.fonts.primary, 
        Main.Global.rootScene);

    Main.Global.renderHooks.push((time) -> {
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

  public static function tempText(
      font, 
      text) {

    tempTf.font = font;
    tempTf.text = text;

    return tempTf; 
  }

  public static function homeMenu(
      onSelect, 
      options: Array<Array<String>>) {
    final font = Main.Global.fonts.primary;
    final itemPadding = 10;
    final itemSpacing = 10;
    final itemWidth = 300;
    final descenderHeight = 4;
    final state = {
      isAlive: true
    };
    final textAlign = Center;
    final win = hxd.Window.getInstance();
    final options = Lambda.mapi(
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
              Main.Global.uiRoot);

          return tf;
        });

    function cleanup() {
      state.isAlive = false;

      final cleanupTextFields = (tf) -> {
        tf.remove();
        return true;
      }
      Lambda.foreach(
          textFields,
          cleanupTextFields);
    }

    Main.Global.updateHooks.push((dt) -> {
      Main.Global.worldMouse.hoverState = Main.HoverState.Ui;

      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
      final hoveredItem = getHoveredControl(
          options, mx, my);

      if (hoveredItem != null && Main.Global.worldMouse.clicked) { 
        final shouldCleanup = onSelect(hoveredItem.value);

        if (shouldCleanup) {
          cleanup();
          return false;
        }
      }

      for (o in options) {
        o.x = Std.int((win.width / 2) - (itemWidth / 2));
      }

      for (i in 0...textFields.length) {
        final tf = textFields[i];
        final o = options[i];
        final xOffset = switch(textAlign) {
          case Center: itemWidth / 2;
          default: 0;
        };

        tf.text = o.label;
        tf.textAlign = textAlign;
        tf.x = o.x + itemPadding / 2 + xOffset;
        tf.y = o.y + itemPadding / 2;
      }

      return state.isAlive;
    });

    Main.Global.renderHooks.push((dt) -> {
      final mx = Main.Global.uiRoot.mouseX;
      final my = Main.Global.uiRoot.mouseY;
      final hoveredItem = getHoveredControl(
          options, mx, my);

      // render screen overlay
      Main.Global.uiSpriteBatch.emitSprite(
          0,
          0,
          'ui/square_white',
          null,
          (p) -> {
            final b = p.batchElement;
            b.alpha = 0.8;
            b.r = 0;
            b.g = 0;
            b.b = 0;
            b.scaleX = win.width;
            b.scaleY = win.height;
          });

      if (hoveredItem != null) { 
        Main.Global.uiSpriteBatch.emitSprite(
            hoveredItem.x,
            hoveredItem.y,
            'ui/square_white',
            null,
            (p) -> {
              p.batchElement.alpha = 0.8;
              p.batchElement.r = 0.9;
              p.batchElement.g = 0;
              p.batchElement.b = 0.5;
              p.batchElement.scaleX = hoveredItem.width;
              p.batchElement.scaleY = hoveredItem.height;
            });
      }
      
      return state.isAlive;
    });

    return cleanup;
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

