import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:myproject_functions/dates.dart';
import 'package:myproject_functions/values/Matchup.dart';
import 'package:myproject_functions/values/Player.dart';
import 'package:myproject_functions/values/Team.dart';
import 'package:myproject_functions/values/Tournament.dart';
import 'package:myproject_functions/values/TournamentSchedule.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:pool/pool.dart';

final _connectionPool = new Pool(4);

Future<Document> _fetchResource(Uri uri) async {
  try {
    print("$uri");
    final request = await new HttpClient().getUrl(uri);
    final response = await request.close();
    final body = await response.transform(const Utf8Codec().decoder).join();
    return parse(body);
  } catch (e) {
    return _fetchResource(uri);
  }
}

Future<Document> _postResource(Uri uri, Map<String, String> params) async {
  try {
    print("$uri");
    final response = await http.post(uri, body: params);
    print("response status code: ${response.statusCode}");
    return parse(response.body);
  } catch (e) {
    print("Error: $e");
    rethrow;
  }
}

Future<Document> _fetchPGRaw(String res, [Map<String, String> params]) =>
    _connectionPool.withResource(() =>
        _fetchResource(new Uri.https('www.perfectgame.org', res, params)));

Future<Document> _postPGRaw(String res, Map<String, String> params,
        [Map<String, String> querypParams]) =>
    _connectionPool.withResource(() => _postResource(
        new Uri.https('www.perfectgame.org', res, querypParams), params));

Iterable<E> _stride<E>(Iterable<E> it, int stride) sync* {
  while (it.isNotEmpty) {
    yield it.first;
    it = it.skip(stride);
  }
}

Element _ancestorByTag(Element e, String tag) {
  while (e.localName != tag) e = e.parent;
  return e;
}

Future<Document> _fetchTournamentsPage() =>
    _fetchPGRaw('Schedule/Default.aspx', {'Type': 'Tournaments'});

Future<Document> _postTournamentsPage(Map<String, String> params) {
  return _postPGRaw('Schedule/Default.aspx', params, {'Type': 'Tournaments'});
}

Iterable<Element> _getEventBoxes(Document d) => _stride(
    ["Ended", ""]
        .map((s) => "div.${s}EventBox")
        .map(d.querySelectorAll)
        .expand((i) => i),
    2);

Future<Iterable<Tournament>> _fetchTournamentsData(
    {Map<String, String> params = null}) async {
  final doc = await _fetchTournamentsPage();
  if (params != null) {
    _scrapeTournamentPostParameters(doc, params);
  }
  return _getEventBoxes(doc).map(_getEventData);
}

Future<Iterable<Tournament>> _postTournamentsData(
    Map<String, String> params) async {
  final doc = await _postTournamentsPage(params);
  _scrapeTournamentPostParameters(doc, params);

  print("doc.text: \n\n ${doc.text} \n\n");

  return _getEventBoxes(doc).map(_getEventData);
}

Future<Document> _fetchTournamentTeamPage(Team t) =>
    _fetchPGRaw('Events/Tournaments/Teams/Default.aspx', {'team': t.id});

Iterable<Player> _getTournamentTeamRoster(Document doc) =>
    doc.querySelectorAll('tr a[id*="Roster"]').map((r) {
      final Element row = _ancestorByTag(r, 'tr');
      return new Player.unpopulated(
          pgid: _getID(r),
          name: r.text,
          pos: row.querySelector('*[id*="Position"]').text,
          year: new RegExp(r'20\d\d').stringMatch(row.text));
    });

Matchup _getMatchupForRows(DateTime day, Element game, Element teams) =>
    new Matchup(
        gameid: game.children[0].children[0].text,
        playtime: Dates.parsePGTime(day, game.children[0].children[1].text),
        maplink: game
            .querySelector('a[href*="maps.google.com"]')
            ?.attributes['href'],
        location: game.children[1].children[0].nodes
            .where((n) => !(n.attributes['id']?.contains('cleatrule') ?? false))
            .map((n) => n.text)
            .join()
            .split(new RegExp(r'\s+'))
            .join(' ')
            .trim(),
        teams: teams
            .querySelectorAll('a[href*="Tournaments/Teams"]')
            .map(_teamFromElement)
            .toList());

Iterable<Matchup> _getEventMatchups(Document d) sync* {
  final dateText = d.querySelector('*[id*="ScheduleDate"]')?.text;
  final DateTime day =
      dateText != null ? Dates.parsePGMedium(dateText) : new DateTime.now();
  final games =
      d.querySelector('div[id*="FullSchedule"]')?.querySelectorAll('div.row') ??
          [];
  final gameData = _stride(games, 2).iterator;
  final teams = _stride(games.skip(1), 2).iterator;
  while (gameData.moveNext() && teams.moveNext())
    yield _getMatchupForRows(day, gameData.current, teams.current);
}

Future<Iterable<String>> _getTournamentScheduleDates(String eid) async =>
    (await _fetchPGRaw(
            'Events/TournamentSchedule.aspx', {'event': eid, 'Date': '1/1/1'}))
        .querySelectorAll('a[id*="datepicker"]')
        .map(_getID);

Future<Iterable<Matchup>> _getTournamentScheduleMatchups(String eid) async =>
    (await Future.wait((await _getTournamentScheduleDates(eid)).map((d) =>
            _fetchPGRaw(
                'Events/TournamentSchedule.aspx', {'event': eid, 'Date': d}))))
        .map(_getEventMatchups)
        .expand((l) => l);

Iterable<Element> _getTournamentTeamAnchors(Document d) =>
    d.querySelectorAll('a[href*="Tournaments/Teams/Default.aspx"]');

String _getID(Element anchor) {
  final href = anchor.attributes['href'];
  return href.substring(href.lastIndexOf('=') + 1);
}

Future<Iterable<String>> _expandEventIds(Tournament t) async =>
    t.isGroup ? await _fetchEventsForEventGroup(t.id) : [t.id];

Future<Iterable<Team>> _fetchEventTeams(String eventid) async =>
    _getTournamentTeamAnchors(await _fetchPGRaw(
            'Events/TournamentTeams.aspx', {'event': eventid}))
        .map(_teamFromElement);

Team _teamFromElement(Element e) => new Team(_getID(e), e.text);

Future<List<Team>> _getEventsTeams(Iterable<String> eids) async =>
    (await Future.wait(eids.map(_fetchEventTeams))).expand((l) => l).toList();

Future<Iterable<String>> _fetchEventsForEventGroup(String gid) async =>
    (await _fetchPGRaw('Schedule/GroupedEvents.aspx', {'gid': gid}))
        .querySelectorAll('strong')
        .map((e) => _ancestorByTag(e, 'a'))
        .map(_getID);

Future<TournamentSchedule> _fetchScheduleForTournament(Tournament t) async {
  final eids = (await _expandEventIds(t)).toList();
  final teams = await _getEventsTeams(eids);
  final tpages = await Future.wait(teams.map(_fetchTournamentTeamPage));
  final rosters = new Map.fromIterables(teams.map((t) => t.id),
      tpages.map(_getTournamentTeamRoster).map((r) => r.toList()));
  final matchups = (await Future.wait(eids.map(_getTournamentScheduleMatchups)))
      .expand((l) => l)
      .toList();

  return new TournamentSchedule(
      tournament: t, rosters: rosters, matchups: matchups);
}

Future<List<TournamentSchedule>> _fetchTournamentSchedules(
        {Map<String, String> params = null}) async =>
    Future.wait((await _fetchTournamentsData(params: params))
        .map(_fetchScheduleForTournament));

Future<List<TournamentSchedule>> _postTournamentSchedules(
        Map<String, String> params) async =>
    Future.wait(
        (await _postTournamentsData(params)).map(_fetchScheduleForTournament));

Future<Map<DateTime, List<TournamentSchedule>>> dpgsGetTournamentSchedulesMap(
    [int nMonthsToScrape = 1]) async {
  final postParameters = _getDefaultTournamentPostParameters();
  final months = _getTournamentFilterMonths();

  DateTime key = new DateTime.now();
  key = new DateTime(key.year, key.month);

  Map<DateTime, List<TournamentSchedule>> table = {};
  table[key] = await _fetchTournamentSchedules(params: postParameters);

  for (int i = 1; i < nMonthsToScrape; ++i) {
    final nextMonth = Dates.nextMonth(key);

    if (!Dates.isSameYear(key, nextMonth)) {
      // We have to update the year first
      postParameters["__EVENTTARGET"] = "ctl00\$ContentPlaceHolder1\$ddlYear";
      postParameters["ctl00\$ContentPlaceHolder1\$ddlYear"] =
          "${nextMonth.year}";
      await _postTournamentSchedules(postParameters);
    }

    postParameters["__EVENTTARGET"] = months[Dates.months[nextMonth.month - 1]];
    table[nextMonth] = await _postTournamentSchedules(postParameters);
    key = nextMonth;
  }

  return table;
}

Tournament _getEventData(Element ebox) {
  final titleLocElem = ebox.querySelector("center");
  final anchor = _ancestorByTag(ebox, 'a');
  return new Tournament(
      id: _getID(anchor),
      title: titleLocElem.querySelector("strong").text,
      location: titleLocElem.nodes[2].text,
      isGroup: anchor.attributes['href'].contains('Grouped'),
      date:
          ebox.querySelector('div[style="font-weight:bold; float:left"]').text);
}

// No need to actually scrape this.
Map<String, String> _getTournamentFilterMonths() => {
      "January": "ctl00\$ContentPlaceHolder1\$lbFirst",
      "February": "ctl00\$ContentPlaceHolder1\$lbSecond",
      "March": "ctl00\$ContentPlaceHolder1\$lbThird",
      "April": "ctl00\$ContentPlaceHolder1\$lbFourth",
      "May": "ctl00\$ContentPlaceHolder1\$lbFifth",
      "June": "ctl00\$ContentPlaceHolder1\$lbSixth",
      "July": "ctl00\$ContentPlaceHolder1\$lbSeventh",
      "August": "ctl00\$ContentPlaceHolder1\$lbEighth",
      "September": "ctl00\$ContentPlaceHolder1\$lbNinth",
      "October": "ctl00\$ContentPlaceHolder1\$lbTenth",
      "November": "ctl00\$ContentPlaceHolder1\$lbEleventh",
      "December": "ctl00\$ContentPlaceHolder1\$lbTwelveth"
    };

// No need to actually scrape this.
Map<String, String> _getDefaultTournamentPostParameters() => {
      "__ASYNCPOST": "false",
      "__EVENTARGUMENT": "",
      "__EVENTTARGET": "",
      "__EVENTVALIDATION": "",
      "__LASTFOCUS": "",
      "__VIEWSTATE": "",
      "__VIEWSTATEGENERATOR": "",
      "ctl00\$ContentPlaceHolder1\$ddlAgeDivision": "0",
      "ctl00\$ContentPlaceHolder1\$ddlState": "ZZ",
      "ctl00\$ContentPlaceHolder1\$ddlYear": Dates.getCurrentYear(),
      "ctl00\$ContentPlaceHolder1\$rblTournaments": "1,2,3"
    };

// Unfortunately, we need to pass the postParameters by reference.
void _scrapeTournamentPostParameters(
    Document doc, Map<String, String> postParameters) {
  // Do NOT get rid of these helper functions!
  // The attributes map can be null, so doing a simple attributes["value"] will cause a crash.
  // The putIfAbsent method returns null for empty strings for some reason.
  String getAttributeValue(String id) {
    final attributes = doc.getElementById(id)?.attributes;
    return (attributes != null) ? attributes["value"] ?? "" : "";
  }

  String getSelectedAttributeValue(String id, {String defaultValue = ""}) {
    final attributes = doc
        .getElementById(id)
        ?.querySelector("option[selected='selected']")
        ?.attributes;

    return (attributes != null)
        ? attributes["value"] ?? defaultValue
        : defaultValue;
  }

  postParameters["__EVENTARGUMENT"] = getAttributeValue("__EVENTARGUMENT");
  postParameters["__EVENTTARGET"] = getAttributeValue("__EVENTTARGET");
  postParameters["__EVENTVALIDATION"] = getAttributeValue("__EVENTVALIDATION");
  postParameters["__VIEWSTATE"] = getAttributeValue("__VIEWSTATE");
  postParameters["__VIEWSTATEGENERATOR"] =
      getAttributeValue("__VIEWSTATEGENERATOR");
  postParameters["ctl00\$ContentPlaceHolder1\$ddlYear"] =
      getSelectedAttributeValue("ContentPlaceHolder1_ddlYear",
          defaultValue: Dates.getCurrentYear());

  // ZZ decodes to all states.
  postParameters["ctl00\$ContentPlaceHolder1\$ddlState"] =
      getSelectedAttributeValue("ContentPlaceHolder1_ddlState",
          defaultValue: "ZZ");

  // 0 decodes to all age divisions.
  postParameters["ctl00\$ContentPlaceHolder1\$ddlAgeDivision"] =
      getSelectedAttributeValue("ContentPlaceHolder1_ddlAgeDivision",
          defaultValue: "0");
}
