import TestUtils.assert;
import haxe.Serializer;
import haxe.Unserializer;
using Lambda;

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
    persistToUrl: String,
    onSuccess: (res: Dynamic) -> Void,
    onError: (e: Dynamic) -> Void
  ) {
    var serializer = new Serializer();
    serializer.serialize(data);
    var serialized = serializer.toString();

    try {
    #if jsMode
      var ls = Browser.getLocalStorage();
      ls.setItem(keyPath, serialized);

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

  public static function load(keyPath: String): Dynamic {
    #if jsMode
    {
      var ls = Browser.getLocalStorage();
      var s = ls.getItem(keyPath);

      if (s == null) {
        return s;
      }

      var unserializer = new Unserializer(s);

      return unserializer.unserialize();
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

        SaveState.save(data, keyPath, null, (_) -> {
          var s: Map<String, Int> = SaveState.load(keyPath);
          var isEqualState = [for (k in s.keys()) k]
            .foreach((k) -> {
              data[k] == s[k];
            });

          hasPassed(isEqualState);
        }, (e) -> {
          trace(e);
          hasPassed(false);
        });
      }, () -> {
        SaveState.delete(keyPath);
      });

      assert('[SaveState] delete state', (hasPassed) -> {
        SaveState.save({
          foo: 'foo'
        }, keyPath, null, (_) -> {
          SaveState.delete(keyPath);

          hasPassed(
            SaveState.load(keyPath) == null
          );
        }, (e) -> {
          trace(e);
          hasPassed(false);
        });
      });
    }
    #end
  }
}