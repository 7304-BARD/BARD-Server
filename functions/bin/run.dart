import 'package:myproject_functions/data_access/dpgs.dart';

void main() async {
  final start = new DateTime.now();
  print("$start");

  await dpgsUpdateTournamentSchedules();

  final finish = new DateTime.now();
  print("$start");
  print("$finish");
}
