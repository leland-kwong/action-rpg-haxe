#if (target.threaded)
import sys.thread.Thread;
#end

import sys.FileSystem;
import sys.io.File;

typedef SessionEvent = {
  type: String,
  data: Dynamic,
  timestamp: Float
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

  static function makeId(
      ?customId: String) {
    return Utils.withDefault(
        customId, 
        '${Std.int(Sys.time())}');
  }

  public static function createGame(
      ?previousState: SessionRef, 
      ?previousLogData: String,
      ?customId: String): SessionRef {

    final id = makeId(customId);
    final sessionId = 'session_${id}';

    // create game state from previous state and log
    if (previousState != null) {
      final newState = Reflect.copy(previousState);

      processLog(newState, previousLogData);
      // create a new session id for new state
      newState.sessionId = sessionId;

      return newState;
    }

    return {
      gameId: 'game_${id}',
      sessionId: id,
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

  static function serialize(data: Dynamic): String {
    return haxe.Serializer.run(data);
  }

  static function deserialize(rawData: String): Dynamic {
    return haxe.Unserializer.run(rawData);
  }

  public static function makeEvent(
      eventType: String,
      eventDetail: Dynamic): SessionEvent {
    return {
      type: eventType,
      data: eventDetail,
      timestamp: Sys.time()
    };
  }

  static final threadMessageQueue: 
   Array<{
     file: String,
     event: SessionEvent,
     onSuccess: () -> Void
   }> = [];

  // logs the event to disk
  public static function logEventToDisk(
      ref: SessionRef, 
      event: SessionEvent,
      ?onSuccess: () -> Void,
      ?onError: (err: Dynamic) -> Void) {

    final file = SaveState.filePath(
        savedGamePath(ref));

    threadMessageQueue.push({
      file: file,
      event: event,
      onSuccess: onSuccess
    });

    if (thread == null) {
#if (target.threaded)
      thread = Thread.create(() -> {
        try {
          while (true) {
#end
            while (threadMessageQueue.length == 0) {
              Sys.sleep(10 / 1000);
            }

            final nextMessage = threadMessageQueue.shift();
            final event: SessionEvent = nextMessage.event;
            final file = nextMessage.file;
            final isNewFile = !fileOutputByPath.exists(file);

            final fileOutput = {
              if (isNewFile) {
                final keypath = file.split('/');
                final saveDir = keypath.slice(0, -1).join('/');

                if (!FileSystem.exists(saveDir)) {
                  FileSystem.createDirectory(saveDir);
                }

                final shouldCreateNewFile = !FileSystem.exists(file);

                if (shouldCreateNewFile) {
                  File.saveContent(file, '');
                }

                final fileOutput = sys.io.File.append(
                    file, false);

                fileOutputByPath.set(file, fileOutput);
                fileOutput;
              } else {
                fileOutputByPath.get(file);
              }
            }

            // add current state to head of file
            if (isNewFile) {
              File.saveContent(
                  file, serialize(ref));
            }

            fileOutput.writeString(
                '${delimiter}${serialize(event)}',
                UTF8);
            fileOutput.flush();

            if (nextMessage.onSuccess != null) {
              nextMessage.onSuccess();
            }
#if (target.threaded)
          }
        } catch (error: Dynamic) {

          if (onError != null) {
            onError(error);
          } else {
            HaxeUtils.handleError(
                '',
                (_) -> hxd.System.exit())(error);
          }
        }
      }); 
#end
    }
  }

  static function processEvent(
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

  static final savedGamesRootDir = 'saved-games';

  static function savedGameDir(gameId) {
    return '${savedGamesRootDir}/${gameId}';
  }

  static function savedGamePath(
      ref: SessionRef) {
    return '${savedGameDir(ref.gameId)}/${ref.sessionId}.log';
  }

  public static function logAndProcessEvent(
      ref, 
      event: SessionEvent,
      ?onSuccess) {

    logEventToDisk(ref, event, onSuccess);
    processEvent(ref, event);
  }

  public static function processLog(
      ref: SessionRef,
      logData: String) {
    final events = logData.split(delimiter);

    for (evString in events) {
      final parsed: SessionEvent = deserialize(evString);
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

  static function handleLoadGame(rawGameData: String): SessionRef {
    final firstDelimIndex = rawGameData.indexOf(delimiter);
    final ref: SessionRef = deserialize(rawGameData.substring(0, firstDelimIndex));
    final eventLog = rawGameData.substring(firstDelimIndex + 1);

    final isValidRef = Type.typeof(ref) == TObject
      && HaxeUtils.hasSameFields(ref, createGame());

    if (!isValidRef) {
      throw new haxe.Exception(
          '[session load error] invalid session ref');
    }

    return createGame(ref, eventLog);
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
  public static function loadGameFile(
      gameFile: String,
      onSuccess,
      onError) {

    // the log data is a newline delimited
    // list of serialized events, so we have to
    // do some custom processing instead of 
    // deseriazling in one shot
    function noDeserialize(rawData: String) {
      return rawData;
    }

    function onGameLoaded(gameData: String) {
      onSuccess(handleLoadGame(gameData));
    }

    SaveState.load(
      gameFile,
      false,
      noDeserialize,
      onGameLoaded,
      onError);
  }

  public static function getGamesList() {
    final gameDirs = FileSystem.readDirectory(
        SaveState.filePath(
          savedGamesRootDir));

    return gameDirs;
  }

  public static function deleteGame(
      gameId: String, 
      onSuccess, 
      onError) {

    try {
      final dir = SaveState.filePath(
          savedGameDir(gameId));
      if (FileSystem.exists(dir)) {
        final files = FileSystem.readDirectory(dir);
        // need to clear directory first
        for (f in files) {
          final path = '${dir}/${f}';
          final fileOutput = fileOutputByPath.get(path);

          if (fileOutput != null) {
            fileOutput.close();
            fileOutputByPath.remove(path);
          }

          FileSystem.deleteFile(path);
        }
        FileSystem.deleteDirectory(dir);
      }
      onSuccess();
    } catch (err) {
      onError(err);
    }
  }

  public static function tests() {
    final mockNodeId = 'unit_test_nodeid';
    final mockEvent = Session.makeEvent(
        'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION', {
          nodeId: mockNodeId
        });

    TestUtils.assert(
        'log event and load game',
        (passed) -> {
          final stateRef = Session.createGame(
              null,
              null,
              'unit_test_id');

          function onError(err) {
            HaxeUtils.handleError(null)(err);
            deleteGame(
                stateRef.gameId,
                () -> {},
                HaxeUtils.handleError('error deleting file'));
          }

          Session.logEventToDisk(stateRef, mockEvent, () -> {
            final gameFile = savedGamePath(stateRef);
            Session.loadGameFile(
                gameFile,
                (loadedStateRef) -> {
                  passed(
                      stateRef.sessionId != loadedStateRef.sessionId);

                  deleteGame(
                      stateRef.gameId,
                      () -> {},
                      HaxeUtils.handleError('error deleting file'));
                },
                onError);
          }, onError);
        });

    TestUtils.assert(
        'list games',
        (passed) -> {
          final stateRefsList = [
            for (i in 0...2) 
              Session.createGame(
                  null,
                  null,
                  'unit_test_id_${Utils.irnd(0, 1000)}')];    
          var numLogged = 0;

          function checkGamesList() {
            if (numLogged != stateRefsList.length) {
              return;
            }

            final gamesList = getGamesList();

            function hasGameId(ref) {
              return Lambda.exists(
                  gamesList, 
                  (gameId) -> gameId == ref.gameId);
            }

            passed(
                Lambda.foreach(
                  stateRefsList, 
                  hasGameId));

            // cleanup
            for (gameId in gamesList) {
              deleteGame(
                  gameId,
                  () -> {},
                  HaxeUtils.handleError(null));
            }
          }

          for (stateRef in stateRefsList) {
            Session.logEventToDisk(
                stateRef, mockEvent, () -> {
                  numLogged += 1;
                  checkGamesList();
                });
          }
        });
  }
}

