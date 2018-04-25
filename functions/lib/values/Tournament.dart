import 'package:meta/meta.dart';

class Tournament {
  final String title;
  final String date; // may be a range of dates. See [dates] property.
  final String location; // general location, such as a city
  final String id;

  // Most tournaments are event groups, which contain several sub-events.
  // dpgs handles both single events and groups.
  // isGroup distinguishes which kind of [id] we have.
  final bool isGroup;

  const Tournament(
      {@required this.id,
      @required this.title,
      @required this.date,
      @required this.location,
      @required this.isGroup});

  Map<String, dynamic> toMap() => {
        'title': title,
        'date': date,
        'location': location,
        'id': id,
        'isGroup': isGroup ? 1 : 0
      };
}
