import 'dart:convert';

import 'package:http/http.dart' as http;

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


}