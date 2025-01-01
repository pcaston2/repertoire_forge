// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:repertoire_forge/chess_dot_com_client.dart';

import 'package:repertoire_forge/main.dart';

void main() {
  test('Get data from Chess.com', () async {
    //arrange
    var uri = Uri.parse("https://api.chess.com/pub/player/pcaston2/games/archives");
    //act
    http.Response response = await http.get(uri);
    Map<String,dynamic> data = jsonDecode(response.body);
    dynamic archives= data["archives"];
    //assert
    expect(archives, isNotEmpty, reason: 'There should be games in the archive');
  });

  test('Get data from Chess.com through client', () async {
    //arrange
    var client = ChessDotComClient("pcaston2");
    //act
    var archives = await client.getArchives();
    //assert
    expect(archives, isNotEmpty, reason: 'There should be games in the archive');
    expect(archives.first, equals("https://api.chess.com/pub/player/pcaston2/games/2016/04"), reason: "This should be the first archive");
  });
}
