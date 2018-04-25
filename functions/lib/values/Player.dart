import 'package:meta/meta.dart';

class Player {
  String pgid;
  String name;
  String year;
  String pos;

  Player.unpopulated(
      {@required this.pgid,
      @required this.name,
      @required this.pos,
      @required this.year}) {}

  static Player fromWLEntry(dynamic wle) {
    final pgid = wle.keys.first;
    return new Player.unpopulated(
        pgid: pgid,
        name: wle[pgid]['name'],
        pos: wle[pgid]['pos'],
        year: wle[pgid]['year']);
  }

  Map<String, Map<String, dynamic>> toWLEntry() => {
        pgid: {
          'name': name,
          'year': year,
          'pos': pos,
        }
      };
}
