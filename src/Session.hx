import sys.thread.Thread;
import sys.FileSystem;
import sys.io.File;

typedef SessionEvent = {
  type: String,
  data: Dynamic
};

typedef SessionRef = {
  sessionId: String,
  gameId: String,
  // level can be derived from this
  experienceGained: Int,
  questState: Quest.QuestStateByName,
  inventoryState: Dynamic,
  passiveSkillTreeState: {
    totalPointsAvailable: Int,
    nodeSelectionStateById: 
      Map<String, Bool>
  }
}

class Session {
  static final delimiter = '\n';

  static var thread: Thread;
  public static final fileOutputByPath: 
    Map<String, sys.io.FileOutput> = new Map();

  public static function create(): SessionRef {
    return {
      sessionId: 'session_${Std.int(Sys.time())}',
      gameId: 'game_${Std.int(Sys.time())}',
      experienceGained: 0,
      questState: new Map(),
      inventoryState: 'UNKNOWN_INVENTORY_STATE',
      passiveSkillTreeState: {
        // includes root node which is always selected
        totalPointsAvailable: 10,
        nodeSelectionStateById: [
          'SKILL_TREE_ROOT' => true
        ]
      } 
    };
  }

  // logs the event to disk
  public static function logEvent(
      file: String, 
      payload: SessionEvent,
      ?onSuccess: () -> Void) {

    if (thread == null) {
      thread = Thread.create(() -> {
        try {
          while (true) {
            final nextMessage = Thread.readMessage(true);
            Main.Global.logData.sessionMessage = nextMessage;
            final payload: SessionEvent = nextMessage.payload;
            final file = nextMessage.file;

            final fileOutput = {
              if (fileOutputByPath.exists(file)) {
                fileOutputByPath.get(file);
              } else {
                final keypath = file.split('/');
                final saveDir = keypath.slice(0, -1).join('/');

                if (!FileSystem.exists(saveDir)) {
                  FileSystem.createDirectory(saveDir);
                }
                if (!FileSystem.exists(file)) {
                  File.saveContent(file, '');
                }

                final fileOutput = sys.io.File.append(
                    file, false);

                fileOutputByPath.set(file, fileOutput);
                fileOutput;
              }
            }

            final stringified = haxe.Json.stringify(payload);
            fileOutput.writeString(
                '${payload}${delimiter}',
                UTF8);
            fileOutput.flush();

            if (onSuccess != null) {
              onSuccess();
            }
          }
        } catch (error: Dynamic) {

          final stack = haxe.CallStack.exceptionStack();
          trace(error);
          trace(haxe.CallStack.toString(stack));
          hxd.System.exit();

        }
      }); 
    }

    thread.sendMessage({
      file: file,
      payload: payload,
      timestamp: Sys.time()
    });
  }

  public static function processEvent(
      ref: SessionRef,
      ev: SessionEvent) {
    switch(ev) {
      case { 
        type: 'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION',
        data: d }: {
          final nodeId = d.nodeId;
          final s = ref.passiveSkillTreeState
            .nodeSelectionStateById;
          final currentlySelected = Utils.withDefault(
              s.get(nodeId), false);

          s.set(nodeId, !currentlySelected);
      }

      default: {
        throw 'invalid session event ${ev.type}';
      }
    }
  }

  public static function sessionPath(
      ref: SessionRef) {
    return 'sessions/${ref.sessionId}.log';
  }

  public static function savedGamePath(
      ref: SessionRef) {
    return 'saved-games/${ref.gameId}.sav';
  }

  public static function logAndProcessEvent(
      ref, 
      event: SessionEvent,
      ?onSuccess) {
    final file = SaveState.filePath(
        sessionPath(ref));

#if debugMode
    TestUtils.assert(
        'is incorrect log file path',
        (passed) -> {
          passed(
              file == 'external-assets/${sessionPath(ref)}'); 
        });
#end
    
    logEvent(file, event, onSuccess);
    processEvent(ref, event);
  }

  public static function processLog(
      ref: SessionRef,
      logData: String) {
    final events = logData.split(delimiter);

    for (evString in events) {
      final parsed = haxe.Json.parse(evString);
      processEvent(
          ref,
          parsed);
    }
  }

  public static function saveGame(
      ref: SessionRef,
      onSuccess,
      onError) {

    SaveState.save(
        ref,
        savedGamePath(ref),
        null,
        onSuccess,
        onError);
  }

  public static function createAndSave(
      onSuccess: (ref: SessionRef) -> Void,
      onError: (err: Dynamic) -> Void) {
    
    final ref = create();
    saveGame(
        ref,
        (_) -> {
          onSuccess(ref);
        },
        onError);
  }

  // Loading the game also processes the previous log data
  // to keep the state up to date. This is necessary because
  // we never actually save the state until this point. We just
  // log changes to a log file so we can then lazily load things
  // up at load time. This allows us to quickly save changes in
  // the background without needing to do a full state serializtion
  // on every event.
  // 
  // 1. Loads previous game file
  // 2. Loads previous session log from game file
  // 3. Processes session log to update game state to latest
  // 4. Saves new game state to disk
  public static function loadGame(
      gameFile: String,
      onSuccess,
      onError) {

    function createLogSessionHandler(ref: SessionRef) {
      return function(logData: String) {
        processLog(ref, logData); 
        saveGame(
            ref,
            onSuccess,
            onError);
      }
    }

    // the log data is a newline delimited
    // list of serialized events, so we have to
    // do some custom processing instead of 
    // deseriazling in one shot
    function noDeserialize(rawData: String) {
      return rawData;
    }

    function onRefLoaded(ref: SessionRef) {
      
      final isValidRef = Type.typeof(ref) == TObject
          && HaxeUtils.hasSameFields(ref, create());

      if (!isValidRef) {
        throw new haxe.Exception(
            '[session load error] invalid session ref');
      }

      SaveState.load(
          sessionPath(ref),
          false,
          noDeserialize,
          createLogSessionHandler(ref),
          onError);
    }

    SaveState.load(
      gameFile,
      false,
      null,
      onRefLoaded,
      onError);
  }

  public static function wip() {

    function onCreateSuccess(sessionRef) { 
      Main.Global.inputHooks.push((dt: Float) -> {
        final Key = hxd.Key;

        if (Key.isPressed(Key.S)) {
          Session.logAndProcessEvent(sessionRef, {
            type: 'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION',
            data: {
              nodeId: 'test_nodeid'
            }
          }, () -> {
            trace('log succcess');
            Session.saveGame(
                sessionRef,
                (_) -> trace(
                  'save game success', 
                  Session.savedGamePath(sessionRef)),
                HaxeUtils.handleError(
                  'save game failed'));
          });
        }

        if(Key.isPressed(Key.L)) {
          Session.loadGame(
              Session.savedGamePath(sessionRef),
              (loadedGameRef) -> {
                Main.Global.logData.loadedGameRef = 
                  loadedGameRef;
                // trace('loaded game', loadedGameRef);
              },
              HaxeUtils.handleError(
                'error loading game'));
        }

        return true;
      });
    }    

    Session.createAndSave(
        onCreateSuccess,
        HaxeUtils.handleError(
          'error creating game')
        );
  } 

}

