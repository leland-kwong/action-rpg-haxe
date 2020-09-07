typedef GameAction = {
  type: String,
  // zone at which the action occured
  location: String,
  data: {
    ?questName: String,
    ?type: String,
    ?enemyType: String
  }
};

typedef QuestState = {
  var completed:  Bool;
  var active:  Bool;
  var description:  String;
  var ?numKilled: Int;
};

typedef QuestCondition = {
  defaultState: QuestState,
  calc: (
    action: GameAction, 
    questState: QuestState) -> QuestState
}

// contains all the quest status data
typedef QuestStateByName = Map<String, QuestState>;

typedef ConditionsByName = Map<String, QuestCondition>;
 
class Quest {
  public static final conditionsByName: ConditionsByName = {
    [
      'testQuest' => {
        calc: (action, state) -> {
          if (action.type == 'FINISH_TEST_QUEST') {
            return {
              description: 'Completed',
              active: true,
              completed: true
            };
          }

          return state;
        }, 
        defaultState: {
          description: 'Some test quest',
          active: false,
          completed: false
        }
      },
      'aggressiveBats' => {
        calc: (action, state) -> {
          final numRequirement = 2;

          if (action.type == 'ENEMY_KILL' &&
              action.data.enemyType == 'bat') {
            final numKilled = state.numKilled + 1;
            final numLeftToKill = numRequirement - numKilled;
            final completed = numKilled >= numRequirement;
            final description = completed 
              ? 'completed'
              : 'kill ${numLeftToKill} bats';


            return {
              numKilled: numKilled,
              description: description,
              completed: completed,
              active: true
            };
          }

          return state;
        }, 
        defaultState: {
          description: 'Find and kill bats',
          numKilled: 0,
          active: false,
          completed: false
        }
      },
      'destroyBoss' => {
        calc: (action, state) -> {
          if (action.type == 'ENEMY_KILL' &&
              action.data.enemyType == 'introLevelBoss') {

            return {
              description: 'completed',
              active: true,
              completed: true
            };
          }

          return state;
        }, 
        defaultState: {
          description: 'Find and kill the boss',
          active: false,
          completed: false
        }
      }
    ];
  };

  public static function updateState(
      action: GameAction,
      currentQuestStates: QuestStateByName,
      conditions: ConditionsByName): QuestStateByName {
    final newQuestState = new Map();

    for (name => cond in conditions) {
      final qs = currentQuestStates.get(name);
      final isActivate = action.type == 'ACTIVATE_QUEST'
        && action.data.questName == name;
      final nextState = switch (action.type) {
        case 'ACTIVATE_QUEST' if (action.data.questName == name): {
          final copy = Reflect.copy(qs);
          copy.active = true;
          copy;
        }

        case '@initQuestState': {
          cond.defaultState;
        }

        default: cond.calc(action, qs);
      }

      newQuestState.set(name, nextState);
    }

    return newQuestState;
  }

  public static function createNewState() {
    return updateState(
        createAction(
          '@initQuestState',
          null,
          null),
        new Map(),
        conditionsByName);
  }

  public static function createAction(
      type, 
      location, 
      data: Dynamic) {

    return {
      type: type,
      location: location,
      data: data
    };
  }

  // used for rendering
  public static function format(questState: QuestStateByName) {
    var result = '';

    for (name => state in questState) {
      if (!state.active) {
        continue;
      }

      final description = Utils.withDefault(
          state.description, '');
      final checkmark = state.completed ? 'x' : '  ';
      final nextLine = '${name}\n[${checkmark}] ${description}\n\n';

      result = '${result}${nextLine}';
    }

    return result;
  }
}
