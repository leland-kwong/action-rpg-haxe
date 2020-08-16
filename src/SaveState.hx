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
  static final baseDir = 'external-assets';

  public static function save(
      data: Dynamic,
      file: String,
      serializeFn = null,
      onSuccess: (res: Null<Dynamic>) -> Void,
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
      File.saveContent('${baseDir}/${file}', serialized);
      onSuccess(null);
    }
    catch (err: Dynamic) {
      onError(err);
    }
  }

  public static function load(
    keyPath: String,
    fromUrl = false,
    deserializeFn = null,
    onSuccess: (data: Dynamic) -> Void,
    onError: (error: Dynamic) -> Void
  ): Void {
    try {

      var fullPath = '${baseDir}/${keyPath}';

      if (!FileSystem.exists(fullPath)) {
        onSuccess(null);
        return;
      }

      final s = File.getContent(fullPath);
      final deserialized = {
        if (deserializeFn == null) {
          final unserializer = new Unserializer(s);
          unserializer.unserialize();
        } else {
          deserializeFn(s);
        }
      }

      onSuccess(deserialized);
    }
    catch (error: Dynamic) {
      onError(error);
    }
  }

  public static function delete(keyPath: String) {
    FileSystem.deleteFile('${baseDir}/${keyPath}');
  }

  public static function tests() {
    var rand = '${Math.random() * 1000}'.substring(4);
    var keyPath = 'test_game_state--${rand}.sav';

    #if debugMode {
      // TODO this test is currently not properly deleting the state afterwards
      // assert('[SaveState] save and load', (hasPassed) -> {
      //   var data = [
      //     'foo' => 0,
      //     'bar' => 1
      //   ];

      //   function onError(e) {
      //     trace(e);
      //     hasPassed(false);
      //   }

      //   SaveState.save(data, keyPath, null, (_) -> {
      //     SaveState.load(keyPath, false, (s: Map<String, Int>) -> {
      //       var isEqualState = [for (k in s.keys()) k]
      //         .foreach((k) -> {
      //           data[k] == s[k];
      //         });

      //       hasPassed(isEqualState);
      //     }, onError);
      //   }, onError);
      // }, () -> {
      //   SaveState.delete(keyPath);
      // });

      // assert('[SaveState] delete state', (hasPassed) -> {
      //   function onError(e) {
      //     trace(e);
      //     hasPassed(false);
      //   }

      //   SaveState.save({
      //     foo: 'foo'
      //   }, keyPath, null, (_) -> {
      //     SaveState.delete(keyPath);
      //     SaveState.load(keyPath, (s) -> {
      //       hasPassed(s == null);
      //     }, onError);
      //   }, onError);
      // });
    }
    #end
  }
}
