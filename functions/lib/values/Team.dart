class Team {
  final String id;
  final String name;
  const Team(this.id, this.name);

  Map<String, String> toMap() => {'id': id, 'name': name};
}
