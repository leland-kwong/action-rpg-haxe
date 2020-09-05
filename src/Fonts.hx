class Fonts {
  static var fontCache: 
    Map<hxd.res.BitmapFont, h2d.Font> = new Map();
  
  public static function getFont(
      bmpFont: hxd.res.BitmapFont) {

    if (fontCache.exists(bmpFont)) {
      return fontCache.get(bmpFont);
    }

    fontCache.set(bmpFont, bmpFont.toFont());

    return fontCache.get(bmpFont);
  }

  public static function primary() {
    return getFont(hxd.Res.orbitron_body);
  }

  public static function title() {
    return getFont(hxd.Res.orbitron_title);
  }
}
