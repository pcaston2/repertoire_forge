import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/chess_dot_com_client.dart';

void main() {
  var testUsername = "pcaston2";
  var testArchive = "https://api.chess.com/pub/player/pcaston2/games/2016/04";
  var testGame = "470cf19e-fddc-11e5-8082-00000001000b";

  test('Get data from Chess.com', () async {
    //arrange
    var client = ChessDotComClient(testUsername);
    //act
    var archives = await client.getArchives();
    //assert
    expect(archives, isNotEmpty, reason: 'There should be archives for the games');
    expect(archives.first, equals(testArchive), reason: "This should be the first archive");
  });

  test('Get games from Chess.com in an archive', () async {
    //arrange
    var client = ChessDotComClient(testUsername);
    //act
    var games = await client.getGamesInArchive(testArchive);
    //assert
    expect(games, isNotEmpty, reason: 'There should be games in the archives');
    expect(games.first.uuid, equals(testGame), reason: "This should be the first game");
    expect(games.last.uuid, equals("aeb2c9cc-0282-11e6-8212-00000001000b"), reason: "This should be the last game that archive");
  });

  test('Get games from Chess.com', () async {
    //arrange
    var client = ChessDotComClient(testUsername);
    //act
    var games = await client.getGames();
    //assert
    expect(games, isNotEmpty, reason: 'There should be games in the archives');
    expect(games.first.uuid, equals(testGame), reason: "This should be the first game");
  });
}
