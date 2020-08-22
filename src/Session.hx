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

  public static function create() {
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

  public static function logAndProcessEvent(
      ref, 
      event: SessionEvent,
      ?onSuccess) {
    final file = sessionPath(ref);
    
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
        'saved-games/${ref.gameId}.sav',
        null,
        onSuccess,
        onError);
  }

  public static function loadGame(
      gameId: String,
      onSuccess,
      onError) {

    SaveState.load(
      'saved-games/${gameId}.sav',
      false,
      null,
      onSuccess,
      onError);
  }
}

