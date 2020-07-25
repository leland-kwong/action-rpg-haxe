typedef GameAction = {
  type: String,
  // zone at which the action occured
  location: String,
  data: {
    ?type: String,
    ?enemyType: String
  }
};

typedef QuestState = {
  completed: Bool,
  ?description: String,
  ?numKilled: Int
};

typedef QuestCondition = (
    action: GameAction, 
    questState: QuestState) -> QuestState;

// contains all the quest status data
typedef QuestStateByName = Map<String, QuestState>;

typedef ConditionsByName = Map<String, QuestCondition>;
 
class Quest {
  public static final conditionsByName: ConditionsByName = {
    function createCondition(
        predicate, 
        defaultState): QuestCondition {

      return (action, questState) -> {
        return predicate(
            action, 
            Utils.withDefault(questState, defaultState));
      };
    }

    [
      'aggressiveBats' => createCondition((
            action, 
            state) -> {

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
            completed: completed
          };
        }

        return state;
      }, {
        description: 'find and kill bats',
        numKilled: 0,
        completed: false
      }),
      'destroyBoss' => createCondition((
            action,
            state) -> {

        if (action.type == 'ENEMY_KILL' &&
            action.data.enemyType == 'introLevelBoss') {

          return {
            description: 'completed',
            completed: true
          };
        }

        return state;
      }, {
        description: 'find and kill the boss',
        completed: false
      })
    ];
  };

  public static function updateQuestState(
      action: GameAction,
      currentQuestStates: QuestStateByName,
      conditions: ConditionsByName) {
    final newQuestState = new Map();

    for (name => cond in conditions) {
      final qs = currentQuestStates.get(name);
      newQuestState.set(name, cond(action, qs));
    }

    return newQuestState;
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
      final description = Utils.withDefault(
          state.description, '');
      final checkmark = state.completed ? 'x' : '  ';
      final nextLine = '${name}\n[${checkmark}] ${description}\n\n';

      result = '${result}${nextLine}';
    }

    return result;
  }
}
