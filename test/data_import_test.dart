import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/chess_dot_com_client.dart';
import 'package:repertoire_forge/data_access.dart';
import 'package:repertoire_forge/data_import.dart';
import 'package:repertoire_forge/database.dart';

void main() {
  late DataAccess da;
  late ChessDotComClient client;
  late AppDatabase database;
  String username = 'pcaston2';
  String archiveName = 'https://api.chess.com/pub/player/pcaston2/games/2016/04';
  String gameId = '470cf19e-fddc-11e5-8082-00000001000b';
  String latestGameId = '04719517-c994-11ef-8893-df8f3801000f';
  setUp(() {
    database = AppDatabase(DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
    da = DataAccess(database);
    da.addUser(username);
  });

  tearDown(() async {
    await database.close();
  });


  test('import archives', () async {
    //arrange
    var sut = await DataImport.create(da);
    //act
    await sut.importArchives();
    //assert
    var archives = await sut.dataAccess.archives;
    expect(archives.first.name, equals(archiveName), reason: "This is the first archive");
  });

  test('import games for an archive', () async {
    //arrange
    var sut = await DataImport.create(da);
    await sut.importArchives();
    var archives = await sut.dataAccess.archives;
    //act
    await sut.importGamesInArchive(archives.first.name);
    var game = await da.getGame(gameId);
    //assert
    expect(game.uuid,equals(gameId));
  });

  test('import all games', () async {
    //arrange
    var sut = await DataImport.create(da);
    await sut.importArchives();
    //act
    await sut.importGames();
    var game = await da.getGame(latestGameId);
    //assert
    expect(game.uuid,equals(latestGameId));
  });
}