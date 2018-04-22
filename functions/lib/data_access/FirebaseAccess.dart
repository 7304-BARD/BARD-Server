import 'dart:async';

import 'package:myproject_functions/values/TournamentSchedule.dart';
import 'package:firebase_functions_interop/firebase_functions_interop.dart';

class FirebaseAccess {
  // reference to the Firebase root
  static Future<dynamic> _getDBRootRef() async {
    final fbase = firebaseFunctions.database;
    return await fbase.ref('/');
  }

  // The tsched_v2 key contains a list of JSON-ified TournamentSchedule objects.
  // The TournamentSchedule class is responsible for the representation.
  static Future<dynamic> _getTScheduleDBRef() async =>
      (await _getDBRootRef()).child('tsched_v2');

  static Future<Null> putTournamentSchedules(
      Iterable<TournamentSchedule> ts) async {
    final dbref = await _getTScheduleDBRef();
    await dbref.set(ts.map((t) => t.toMap()).toList());
  }
}
