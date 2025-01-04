import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:repertoire_forge/database.dart';

class ChessDotComClient {
  String _username;
  String get baseUrl => "https://api.chess.com/pub/player/${_username}/games";
  ChessDotComClient(this._username);
  get(String uri) async {
    //arrange
    var requestUri = Uri.parse(uri);
    //act
    http.Response response = await http.get(requestUri);
    Map<String,dynamic> data = jsonDecode(response.body);
    return data;
  }

  Future<List<String>> getArchives() async {
    var archiveJson = await get("${baseUrl}/archives");
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

  Future<List<Game>> getGamesInArchive(String archiveUri) async {
    List<Game> games = [];
    var gamesJson = await get(archiveUri);
    for (var g in gamesJson["games"]) {
      games.add(Game(uuid: g["uuid"], pgn: g["pgn"],archive: archiveUri));
    }
    return games;
  }
}