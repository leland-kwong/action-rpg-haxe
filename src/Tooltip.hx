typedef TooltipContent = {
  content: Array<h2d.Text>,
  position: {
    x: Float,
    y: Float
  }
}

class Tooltip {
  public static final defaultContent = {
    content: [],
    position: {
      x: 0.,
      y: 0.
    }
  }

  static var content: TooltipContent = defaultContent;
  static var root: h2d.Object;

  public static function setContent(
      _content: TooltipContent) {
    content = _content;
  }

  public static function update(_) {
    if (root != null) {
      root.remove();
    }

    root = new h2d.Object(Main.Global.scene.uiRoot);
    root.x = content.position.x;
    root.y = content.position.y;

    Main.Global.logData.contentLength = content.content.length;

    for (c in content.content) {
      root.addChild(c);
    }

    final bounds = root.getBounds(root);
    final background = new h2d.Graphics();
    final padding = 20;
    root.addChildAt(background, 0);
    background.beginFill(0x000000, 0.9);
    background.drawRect(
        bounds.x - padding,
        bounds.y - padding,
        bounds.width + padding * 2,
        bounds.height + padding * 2);

    content = defaultContent;
  }

  public static function render(_) {
  }
}

