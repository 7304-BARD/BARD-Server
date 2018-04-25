import 'package:myproject_functions/values/Matchup.dart';
import 'package:myproject_functions/values/Player.dart';
import 'package:myproject_functions/values/Tournament.dart';
import 'package:meta/meta.dart';

@immutable
class TournamentSchedule {
  final Tournament tournament;
  final List<Matchup> matchups;
  final Map<String, List<Player>> rosters; // key is Team.id

  const TournamentSchedule(
      {@required this.tournament,
      @required this.rosters,
      @required this.matchups});

  Map<String, dynamic> toMap() => {
        'tournament': tournament.toMap(),
        'rosters': new Map.fromIterables(rosters.keys,
            rosters.values.map((l) => l.map((p) => p.toWLEntry()).toList())),
        'matchups': matchups.map((m) => m.toMap()).toList()
      };
}
