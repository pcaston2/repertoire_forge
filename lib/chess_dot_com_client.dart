import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:repertoire_forge/database.dart';

class ChessDotComClient {
  final String _username;
  String get baseUrl => "https://api.chess.com/pub/player/$_username/games";
  ChessDotComClient(this._username);

  Future<Map<String, dynamic>> getJson(String uri) async {
    Map<String,dynamic> data = jsonDecode(await get(uri));
    return data;
  }

  get(String uri) async {
    var requestUri = Uri.parse(uri);
    http.Response response = await http.get(requestUri);
    return response.body;
  }

  Future<List<String>> getArchives() async {
    var archiveJson = await getJson("$baseUrl/archives");
    return List<String>.from(archiveJson["archives"]).map((x) => x.toString()).toList();
  }

  Future<List<Game>> getGames() async {
    var archive = await getArchives();
    List<Game> games = [];
    for(var a in archive) {
      games.addAll(await getGamesInArchive(a));
    }
    return games;
  }

  Future<String> getArchiveHash(String archiveUri) async {
    var text = await get(archiveUri);
    var bytes = utf8.encode(text);
    var value = sha256.convert(bytes);
    return value.toString();
  }

  Future<List<Game>> getGamesInArchive(String archiveUri) async {
    List<Game> games = [];
    var gamesJson = await getJson(archiveUri);
    if (gamesJson["code"] == 0) {
      return [];
    }
    for (var g in gamesJson["games"]) {

      games.add(Game(uuid: g["uuid"], pgn: g["pgn"],archive: archiveUri, reviewed: false, imported: false));

    }
    return games;

    ///, opponentUser: '', oppenentRating: 0, result: '', event: '', site: '', date: DateTime.now(), round: '', white: '', black: '', currentPosition: '', timezone: '', eco: '', ecoUrl: '', utcDate: DateTime.now(), whiteElo: 0, blackElo: 0, timeControl: '', termination: '', startDate: DateTime.now(), endDate: DateTime.now(), link: '', ));

  }
}