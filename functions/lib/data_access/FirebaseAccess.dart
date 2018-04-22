import 'dart:async';

import 'package:myproject_functions/values/TournamentSchedule.dart';
import 'package:firebase/firebase_io.dart';

class FirebaseAccess {
  static Future<Null> putTournamentSchedules(
      Iterable<TournamentSchedule> ts) async {
    return await new FirebaseClient.anonymous().put(
        'https://recruitmentapp-409cd.firebaseio.com/tsched_v2.json',
        ts.map((t) => t.toMap()).toList());
  }
}
