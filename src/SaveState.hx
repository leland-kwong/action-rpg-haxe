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

class SaveState {
  public static final dataCacheByFile: 
    Map<String, Dynamic> = new Map();
  public static function invalidateCache() {
    dataCacheByFile.clear();
  }
  public static final baseDir = 'external-assets';

  public static function filePath(file) {
    return '${baseDir}/${file}';
  }

  public static function save(
      data: Dynamic,
      file: String,
      serializeFn,
      onSuccess: (res: Dynamic) -> Void,
      onError: (e: Dynamic) -> Void) {

    try {
      final keypath = file.split('/');
      final saveDir = keypath.slice(0, -1).join('/');
      final fullSaveDir = '${baseDir}/${saveDir}';

      if (!FileSystem.exists(fullSaveDir)) {
        FileSystem.createDirectory(fullSaveDir);
      }
      final serialized = {
        if (serializeFn != null) {
          serializeFn(data);
        } else {
          haxe.Serializer.run(data);
        }
      };
      final fullPath = '${baseDir}/${file}';
      File.saveContent(fullPath, serialized);
      dataCacheByFile.set(fullPath, data);
      onSuccess(data);
    }
    catch (err: Dynamic) {
      onError(err);
    }
  }

  public static function noData(fileData) {
    return fileData == null;
  }

  // [ENHANCEMENT] improve return value
  // We can return an object of:
  // { data: Dynamic, resolved: Bool, error: Dynamic } 
  // This will solve the issue where we can't tell if a
  // null value being returned is the result no file to load
  // or file was loaded with no data.
  public static function load(
    keyPath: String,
    fromUrl = false,
    ?deserializeFn: (rawData: String) -> Dynamic,
    ?onSuccess: (data: Dynamic) -> Void,
    ?onError: (error: Dynamic) -> Void
  ): Dynamic {
    try {
      final fullPath = '${baseDir}/${keyPath}';

      if (dataCacheByFile.exists(fullPath)) {
        final fromCache = dataCacheByFile.get(fullPath);
        if (onSuccess != null) {
          onSuccess(fromCache);
        }
        return fromCache;
      }

      if (!FileSystem.exists(fullPath)) {
        if (onSuccess != null) {
          onSuccess(null);
        }
        return null;
      }

      final s = File.getContent(fullPath);
      final deserialized = if (deserializeFn == null) {
        haxe.Unserializer.run(s);
      } else {
        deserializeFn(s);
      }

      dataCacheByFile.set(fullPath, deserialized);
      if (onSuccess != null) {
        onSuccess(deserialized);
      }
      return deserialized;
    }
    catch (error: Dynamic) {
      if (onError != null) {
        onError(error);
      }
      return error;
    }

    return null;
  }

  public static function delete(keyPath: String) {
    final fullPath = '${baseDir}/${keyPath}';
    dataCacheByFile.remove(fullPath);
    FileSystem.deleteFile(fullPath);
  }

  public static function tests() {
    var keyPath = 'test_game_state.sav';

    #if debugMode {
      // TODO this test is currently not properly deleting the state afterwards
      assert('[SaveState] save and load', (hasPassed) -> {
        var data = {
          foo: 1,
          bar: 2
        };

        function onError(e) {
          trace(e);
          hasPassed(false);
        }

        SaveState.save(data, keyPath, null, (_) -> {
          function isEqualState(data, s) {
            return [for (k in Reflect.fields(s)) k]
              .foreach((k) -> {
                Reflect.field(data, k) == Reflect.field(s, k);
              });
          }

          var asyncPassed = false;
          SaveState.load(
              keyPath, 
              false, 
              null,
              (s: Dynamic) -> {
            asyncPassed = isEqualState(data, s);
          }, onError);

          final synchronousValue = SaveState.load(
              keyPath, false, null,
              (_) -> {}, onError);

          hasPassed(
              asyncPassed
              && isEqualState(data, synchronousValue));
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
          SaveState.load(keyPath, false, null, (s) -> {
            hasPassed(s == null);
          }, onError);
        }, onError);
      });
    }
    #end
  }
}
