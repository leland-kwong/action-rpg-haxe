import TestUtils.assert;
import haxe.Serializer;
import haxe.Unserializer;
using Lambda;
using StringTools;

#if jsMode
import js.Browser;
#else
import sys.FileSystem;
import sys.io.File;
#end

/**
  TODO
  Add support for save/loading to native file system
**/
class SaveState {
  static var saveDir = 'saved_states';

  public static function save(
    data: Dynamic,
    keyPath: String,
    persistToUrl: Null<String>,
    onSuccess: (res: Null<Dynamic>) -> Void,
    onError: (e: Dynamic) -> Void
  ) {
    var serializer = new Serializer();
    serializer.serialize(data);
    var serialized = serializer.toString();

    try {
    #if jsMode
      if (persistToUrl != null) {
        var fetch = js.Browser.window.fetch;

        fetch(
          new js.html.Request(persistToUrl),
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            body: haxe.Json.stringify({
              data: serialized,
              file: keyPath
            })
          }
        )
        .then(onSuccess)
        .catchError(onError);
      }
      else {
        var ls = Browser.getLocalStorage();
        ls.setItem(keyPath, serialized);
        onSuccess(null);
      }
    #else
      if (!FileSystem.exists(saveDir)) {
        FileSystem.createDirectory(saveDir);
      }
      File.saveContent('${saveDir}/${keyPath}', serialized);
    #end
    }
    catch (err: Dynamic) {
      onError(err);
    }
  }

  public static function load(
    keyPath: String,
    fromUrl = false,
    onSuccess: (data: Dynamic) -> Void,
    onError: (error: Dynamic) -> Void
  ): Void {
    try {

    #if jsMode
    if (fromUrl) {
      var fetch = js.Browser.window.fetch;

      fetch(new js.html.Request(keyPath))
        .then(res -> res.json())
        .then((res: {ok: Bool, data: Null<String>, error: Null<String>}) -> {
          if (res.ok) {
            return res.data;
          }
          else {
            throw res.error;
          }
        })
        .then((data) -> {
          if (data == null) {
            onSuccess(null);
            return;
          }

          var unserializer = new Unserializer(data);
          onSuccess(unserializer.unserialize());
        })
        .catchError(onError);
    }
    else {
      var ls = Browser.getLocalStorage();
      var s = ls.getItem(keyPath);

      if (s == null) {
        onSuccess(null);
        return;
      }

      var unserializer = new Unserializer(s);

      onSuccess(unserializer.unserialize());
    }
    #else
    {
      var fullPath = '${saveDir}/${keyPath}';

      if (!FileSystem.exists(fullPath)) {
        return null;
      }

      var s = File.getContent(fullPath);
      var unserializer = new Unserializer(s);

      return unserializer.unserialize();
    }
    #end

    }
    catch (error: Dynamic) {
      onError(error);
    }
  }

  public static function delete(keyPath: String) {
    #if jsMode
    {
      var ls = Browser.getLocalStorage();
      ls.removeItem(keyPath);
    }
    #else
    {
      FileSystem.deleteFile('${saveDir}/${keyPath}');
    }
    #end
  }

  public static function tests() {
    var rand = '${Math.random() * 1000}'.substring(4);
    var keyPath = 'test_game_state--${rand}.sav';

    #if debugMode {
      assert('[SaveState] save and load', (hasPassed) -> {
        var data = [
          'foo' => 0,
          'bar' => 1
        ];

        function onError(e) {
          trace(e);
          hasPassed(false);
        }

        SaveState.save(data, keyPath, null, (_) -> {
          SaveState.load(keyPath, false, (s: Map<String, Int>) -> {
            var isEqualState = [for (k in s.keys()) k]
              .foreach((k) -> {
                data[k] == s[k];
              });

            hasPassed(isEqualState);
          }, onError);
        }, onError);
      }, () -> {
        SaveState.delete(keyPath);
      });

      assert('[SaveState] delete state', (hasPassed) -> {
        function onError(e) {
          trace(e);
          hasPassed(false);
        }

        SaveState.save({
          foo: 'foo'
        }, keyPath, null, (_) -> {
          SaveState.delete(keyPath);
          SaveState.load(keyPath, (s) -> {
            hasPassed(s == null);
          }, onError);
        }, onError);
      });
    }
    #end
  }
}