#if (target.threaded)
import sys.thread.Thread;
#end

import sys.FileSystem;
import sys.io.File;

typedef SessionEvent = {
  type: String,
  data: Dynamic,
  time: Float
};

typedef SessionRef = {
  sessionId: String,
  gameId: String,
  // Game slot that it was created at.
  // This is used for the ui to show it
  // in a consistent position
  slotId: Int,
  // level can be derived from this
  experienceGained: Int,
  questState: Quest.QuestStateByName,
  inventoryState: {
    equippedAbilitiesById: haxe.ds.Vector<String>,
    itemsById: Map<String, Loot.LootInstance>,
    invGrid: Grid.GridRef
  },
  passiveSkillTreeState: {
    nodeSelectionStateById: 
      Map<String, Bool>
  },
  lastUpdatedAt: Float 
}

typedef ThreadMessage = {
  ref: SessionRef,
  file: String,
  event: SessionEvent,
  onSuccess: () -> Void,
  flushImmediate: Bool
}

class Session {
  static final state = {
    thread: null,
    fileOutputByGameId: new Map<String, sys.io.FileOutput>(),
    threadMessageQueue: new Array<ThreadMessage>()
  };

  static final delimiter = '\n';
  static final NO_UPDATE_YET = -1;

  static function makeId(
      ?customId: String) {
    return Utils.withDefault(
        customId, 
        '${Std.int(Sys.time())}');
  }

  static function serialize(data: Dynamic): String {
    return haxe.Serializer.run(data);
  }

  static function deserialize(rawData: String): Dynamic {
    return haxe.Unserializer.run(rawData);
  }

  // [SIDE-EFFECT] writes data to disk
  static function writeMessageToDisk(
      nextMessage: ThreadMessage) {
    final event: SessionEvent = nextMessage.event;
    final file = nextMessage.file;
    final gameId = nextMessage.ref.gameId;
    final isNewFile = !state.fileOutputByGameId.exists(gameId);

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

        final fileOutput = sys.io.File.append(file);

        state.fileOutputByGameId.set(gameId, fileOutput);
        fileOutput;
      } else {
        state.fileOutputByGameId.get(gameId);
      }
    }

    // add current state to head of file
    if (isNewFile) {
      File.saveContent(
          file, serialize(nextMessage.ref));
    }

    fileOutput.writeString(
        '${delimiter}${serialize(event)}',
        UTF8);

    if (nextMessage.flushImmediate) {
      fileOutput.flush();
    }

    if (nextMessage.onSuccess != null) {
      nextMessage.onSuccess();
    }
  }

  static function logEventToDisk(
      ref: SessionRef, 
      event: SessionEvent,
      ?onSuccess: () -> Void,
      ?onError: (err: Dynamic) -> Void,
      ?flushImmediate = false) {

    final file = SaveState.filePath(
        savedGamePath(ref));
    final message = {
      ref: ref,
      file: file,
      event: event,
      onSuccess: onSuccess,
      flushImmediate: flushImmediate
    };

    if (flushImmediate) {
      writeMessageToDisk(message);
    } else {
      state.threadMessageQueue.push(message);
    }

#if (target.threaded)
    if (state.thread == null) {
      state.thread = Thread.create(() -> {
        try {
          while (true) {
#end
            final nextMessage = state.threadMessageQueue.shift();

            if (nextMessage == null) {
              Sys.sleep(10 / 1000);
              continue;
            }

            // IMPORTANT: thread callback must be pure to 
            // prevent issues with referencing wrong data
            // due to thread asynchronicity.
            writeMessageToDisk(nextMessage);

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
    }
#end
  }

  static final savedGamesRootDir = 'saved-games';

  static function savedGameDir(gameId) {
    return '${savedGamesRootDir}/${gameId}';
  }

  static function savedGamePath(
      ref: SessionRef) {
    return '${savedGameDir(ref.gameId)}/${ref.sessionId}.log';
  }

  static function processLog(
      ref: SessionRef,
      logData: String): Bool {

    final isEmptyLog = logData.length == 0;

    if (isEmptyLog) {
      return false;
    }

    final events = logData.split(delimiter);

    for (evString in events) {
      final parsed: SessionEvent = deserialize(evString);
      processEvent(
          ref,
          parsed);
    }

    return events.length > 0;
  }
  
  public static function handleDidPlayerLevelUp(
      oldExp, 
      newExp) {
    final oldLevel = Config.calcCurrentLevel(oldExp);
    final newLevel = Config.calcCurrentLevel(newExp);

    // trace(oldLevel, newLevel);

    return oldLevel < newLevel;
  }

  // this function should be pure and not
  // access external state like querying for
  // entities.
  public static function processEvent(
      ref: SessionRef,
      ev: SessionEvent) {
    final oldRef = Reflect.copy(ref);

    switch(ev) {
      case {
        type: 'GAME_LOADED',
      }: {
        if (isEmptyGameState(ref)) {
          trace('new game created', ref.gameId);
        } else {
          trace('game reloaded', ref.gameId);  
        }
      }

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

      case {
        type: 'ENEMY_KILLED',
        data: d
      }: {
        final enemyType = d.enemyType;
        final experienceReward = Config.enemyStats.get(enemyType)
          .experienceReward;

        ref.experienceGained += experienceReward;

        final questAction = Quest.createAction(
              'ENEMY_KILL', 
              'intro_level',
              { enemyType: enemyType });
        ref.questState = Quest.updateState(
            questAction,
            ref.questState,
            Quest.conditionsByName);
      }

      case {
        type: 'INVENTORY_INSERT_ITEM',
        data: d
      }: {
        final cx = d.x;
        final cy = d.y;
        final width = d.width;
        final height = d.height; 
        final lootInstance = d.lootInstance;
        final inventoryState = ref.inventoryState;

        Grid.setItemRect(
            inventoryState.invGrid, 
            cx, 
            cy, 
            width, 
            height, 
            lootInstance.id);
        inventoryState.itemsById.set(lootInstance.id, lootInstance);
      }

      case {
        type: 'INVENTORY_REMOVE_ITEM',
        data: itemId
      }: {
        Grid.removeItem(
            ref.inventoryState.invGrid,
            itemId);
        ref.inventoryState.itemsById.remove(itemId);
      }

      default: {
        throw 'invalid session event ${ev.type}';
      }
    }
    ref.lastUpdatedAt = ev.time;

    // handle game notification effects
    final isCurrentGame = Main.Global.gameState.gameId == ref.gameId;
    if (isCurrentGame) {
      if (handleDidPlayerLevelUp(
            oldRef.experienceGained, 
            ref.experienceGained)) {

        // trigger notification side effect
        Effects.playerLevelUp(ref);
      }
    }
    return ref;
  }

  public static function createGameState(
      slotId,
      ?previousState: SessionRef, 
      ?previousLogData: String,
      ?customId: String): SessionRef {

    final id = makeId(customId);
    final sessionId = 'session_${id}';

    // create game state from previous state and log
    if (previousState != null) {
      final newState = Reflect.copy(previousState);
      final hasChanged = processLog(newState, previousLogData);

      if (hasChanged) {
        // create a new session id for new state
        newState.sessionId = sessionId;
      }

      return newState;
    }

    final NULL_PICKUP_ID = Hud
      .InventoryDragAndDropPrototype
      .NULL_PICKUP_ID;

    return {
      gameId: 'game_${id}',
      slotId: slotId,
      sessionId: id,
      experienceGained: 0,
      questState: Quest.createNewState(),
      inventoryState: {
        invGrid: Grid.create(16),
        equippedAbilitiesById: new haxe.ds.Vector(3),
        itemsById: [
          NULL_PICKUP_ID => Loot.createInstance(
              ['nullItem'], NULL_PICKUP_ID)
        ],
      },
      passiveSkillTreeState: {
        // includes root node which is always selected
        nodeSelectionStateById: [
          'SKILL_TREE_ROOT' => true
        ]
      } ,
      lastUpdatedAt: NO_UPDATE_YET
    };
  }

  public static function isEmptyGameState(
      ref: SessionRef) {
    return ref.lastUpdatedAt == NO_UPDATE_YET;
  }

  public static function makeEvent(
      eventType: String,
      ?eventDetail: Dynamic): SessionEvent {

    return {
      type: eventType,
      data: eventDetail,
      time: Sys.time()
    };
  }

  public static function logAndProcessEvent(
      ref: SessionRef, 
      event: SessionEvent,
      ?onSuccess,
      ?onError,
      ?flushImmediate) {

    logEventToDisk(
        ref, event, onSuccess, onError, flushImmediate);
    processEvent(ref, event);
  }

  static function processGameData(rawGameData: String): SessionRef {
    final firstDelimIndex = rawGameData.indexOf(delimiter);
    final ref: SessionRef = deserialize(rawGameData.substring(0, firstDelimIndex));
    final eventLog = rawGameData.substring(firstDelimIndex + 1);

    final isValidRef = Type.typeof(ref) == TObject
      && HaxeUtils.hasSameFields(ref, createGameState(-1));

    if (!isValidRef) {
      throw new haxe.Exception(
          '[session load error] invalid session ref');
    }

    return createGameState(ref.slotId, ref, eventLog);
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
      gameId: String,
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
      final updatedRef = processGameData(gameData);

      onSuccess(updatedRef);
    }

    final fileOutput = state.fileOutputByGameId.get(gameId);
    if (fileOutput != null) {
      fileOutput.flush();
    }

    SaveState.load(
      gameFile,
      false,
      noDeserialize,
      onGameLoaded,
      onError);
  }

  public static function loadMostRecentGameFile(
      gameId: String,
      onSuccess,
      onError) {

    try {
      final gameDir = savedGameDir(gameId);
      final gameFiles = FileSystem.readDirectory(
          SaveState.filePath(gameDir));
      gameFiles.sort((a, b) -> {
        if (a < b) {
          return -1;
        }

        if (a > b) {
          return 1;
        }

        return 0;
      });

      final mostRecent = gameFiles.slice(-1)[0];
      final file = '${gameDir}/${mostRecent}';

      loadGameFile(
          gameId,
          file,
          onSuccess,
          onError);
    } catch (err) {
      onError(err);
    }
  }

  public static function getGamesList() {
    final gameIds = FileSystem.readDirectory(
        SaveState.filePath(
          savedGamesRootDir));

    return gameIds;
  }

  public static function deleteGame(
      gameId: String) {

    final dir = SaveState.filePath(
        savedGameDir(gameId));
    if (FileSystem.exists(dir)) {
      final files = FileSystem.readDirectory(dir);
      // need to clear directory first
      for (f in files) {
        final path = '${dir}/${f}';
        final fileOutput = state.fileOutputByGameId.get(gameId);

        if (fileOutput != null) {
          fileOutput.close();
          state.fileOutputByGameId.remove(gameId);
        }

        FileSystem.deleteFile(path);
      }

      FileSystem.deleteDirectory(dir);
    }
  }

  public static function unitTests() {
    final mockNodeId = 'unit_test_nodeid';
    final mockEvent = Session.makeEvent(
        'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION', {
          nodeId: mockNodeId
        });

    TestUtils.assert(
        'log event and load game',
        (passed) -> {
          final stateRef = Session.createGameState(
              -1,
              null,
              null,
              'unit_test_id');

          function onError(err) {
            HaxeUtils.handleError(null)(err);

            try {
              deleteGame(stateRef.gameId);
            } catch (err) {
              HaxeUtils.handleError('error deleting file')(err);
            }
          }

          Session.logAndProcessEvent(stateRef, mockEvent, () -> {
            final gameFile = savedGamePath(stateRef);
            Session.loadGameFile(
                stateRef.gameId,
                gameFile,
                (loadedStateRef) -> {
                  passed(
                      stateRef.sessionId != loadedStateRef.sessionId);

                  try {
                    deleteGame(stateRef.gameId);
                  } catch (err) {
                    HaxeUtils.handleError('error deleting file');
                  }
                },
                onError);
          }, onError, true);
        });

    TestUtils.assert(
        'list games',
        (passed) -> {
          final stateRefsList = [
            for (i in 0...2) 
              Session.createGameState(
                  -1,
                  null,
                  null,
                  'unit_test_id_${Utils.irnd(0, 1000)}')];    
          var numLogged = 0;

          function checkGamesList() {
            if (numLogged != stateRefsList.length) {
              return;
            }

            final gamesList = Lambda.filter(
                getGamesList(),
                (gameId) -> {
                  return Lambda.exists(
                      stateRefsList, 
                      (ref) -> gameId == ref.gameId);
                });

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
              try {
                deleteGame(gameId);
              } catch (err) {
                HaxeUtils.handleError('error deleting file');
              }
            }
          }

          for (stateRef in stateRefsList) {
            Session.logEventToDisk(
                stateRef, mockEvent, () -> {
                  numLogged += 1;
                  checkGamesList();
                },
                null,
                true);
          }
        });

    {
      final initialRef = Session.createGameState(
          -1,
          null,
          null,
          'unit_test_load_recent');

      TestUtils.assert(
          'get recent game file',
          (passed) -> {
            final stateRefsList = [
              for (i in 0...2) 
                Session.createGameState(
                    initialRef.slotId,
                    initialRef,
                    '',
                    'unit_test_load_recent_${i}')];    
            var numLogged = 0;

            function checkRecentGame() {
              if (numLogged != stateRefsList.length) {
                return;
              }

              loadMostRecentGameFile(
                  initialRef.gameId,
                  (loadedRef) -> {
                    final newestGameId = stateRefsList.slice(-1)[0].gameId;
                    
                    passed(
                        loadedRef.gameId == newestGameId);
                  },
                  HaxeUtils.handleError('error getting recent game file'));
            }

            for (stateRef in stateRefsList) {
              Session.logEventToDisk(
                  stateRef, mockEvent, () -> {
                    numLogged += 1;
                    checkRecentGame();
                  },
                  null,
                  true);
            }
          },
          () -> {
            try {
              deleteGame(initialRef.gameId);
            } catch (err) {
              HaxeUtils.handleError('error deleting file');
            }
          });
    }

    final stressTestEnabled = false;

    if (stressTestEnabled) {
      trace('event logging stress test started');

      final initialRef = Session.createGameState(
          0,
          null,
          null,
          'unit_test_temp_game_state');

      Main.Global.updateHooks.push((dt: Float) -> {
        for (_ in 0...10) {
          Session.logAndProcessEvent(
              initialRef,
              Session.makeEvent(
                'PASSIVE_SKILL_TREE_TOGGLE_NODE_SELECTION',
                { nodeId: 'foobar_node_id' }));  
        }

        return true;
      });
    }

    TestUtils.assert(
        'player should level up',
        (passed) -> {
          passed(
              handleDidPlayerLevelUp(
                Config.levelExpRequirements[0], 
                Config.levelExpRequirements[1]));
        });
  }
}

