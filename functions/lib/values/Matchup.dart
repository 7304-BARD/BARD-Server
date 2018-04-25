import 'package:meta/meta.dart';

import 'package:myproject_functions/values/Team.dart';

/// A single game played in a tournament.
@immutable
class Matchup {
  final String gameid;
  final DateTime playtime;
  final String location; // a specific field or complex
  final List<Team> teams; // should always have length 0 or 2
  final String maplink; // maps.google.com URL

  Matchup(
      {@required this.gameid,
      @required this.playtime,
      @required this.location,
      @required this.teams,
      this.maplink});

  Map<String, dynamic> toMap() => {
        'gameid': gameid,
        'playtime': playtime.toString(),
        'location': location,
        'teams': teams.map((t) => t.toMap()).toList(),
        'maplink': maplink
      };
}
