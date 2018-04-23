import 'dart:async';
import 'package:myproject_functions/data_access/dpgs.dart';
import 'package:myproject_functions/values/TournamentSchedule.dart';
import 'package:firebase/firebase_io.dart';

void main() async {
  final start = new DateTime.now();
  print("$start");

  final map = await dpgsGetTournamentSchedulesMap(6);
  await _putTournamentSchedules(map);

  final finish = new DateTime.now();
  print("$start");
  print("$finish");
}

Future<Null> _putTournamentSchedules(
    Map<DateTime, List<TournamentSchedule>> ts) async {
  final client = new FirebaseClient.anonymous();
  for (final k in ts.keys) {
    await client.put(
        'https://recruitmentapp-409cd.firebaseio.com/tsched_v3/${k.year}/${k.month}.json',
        ts[k].map((s) => s.toMap()).toList());
  }
}
