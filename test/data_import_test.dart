import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/data_access.dart';
import 'package:repertoire_forge/data_import.dart';
import 'package:repertoire_forge/database.dart';

void main() async {
  late DataAccess da;
  late AppDatabase database;
  String username = 'pcaston2';
  String archiveName = 'https://api.chess.com/pub/player/pcaston2/games/2016/04';
  String gameId = '470cf19e-fddc-11e5-8082-00000001000b';
  String latestGameId = '04719517-c994-11ef-8893-df8f3801000f';
  setUp(() async {
    database = AppDatabase.configurable((DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    )));
    da = DataAccess(database);
    await da.setUser(username);
  });

  tearDown(() async {
    await database.close();
  }) ;


  test('import archives multiple times', () async {
    //arrange
    var sut = await DataImport.create(da);
    //act
    await sut.importArchives();
    await sut.importArchives();
    //assert
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
    await for (var _ in sut.importArchives()) {}
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
    await sut.importGamesInAllArchives();
    var game = await da.getGame(latestGameId);
    //assert
    expect(game.uuid,equals(latestGameId));
  });

  test('parse game', () async {
    //arrange
    var sut = await DataImport.create(da);
    await sut.importArchives();
    await sut.importGamesInArchive(archiveName);
    var expectedPosition = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -";
    //act
    await sut.parseGame(gameId);
    var importedPosition = await da.getPosition(expectedPosition);
    var game = await da.getGame(gameId);
    //assert
    expect(importedPosition!.fen, expectedPosition);
    expect(game.isWhite, equals(true));
  });

  test('parse game twice', () async {
    //arrange
    var sut = await DataImport.create(da);
    await sut.importArchives();
    await sut.importGamesInArchive(archiveName);
    //act
    await sut.parseGame(gameId);
    await sut.parseGame(gameId);
    //assert
  });

  test('parse by archive', () async {
    //arrange
    var sut = await DataImport.create(da);
    await sut.importArchives();
    await sut.importGamesInAllArchives();
    //act
    await sut.parseGamesByArchive(archiveName);
    //assert
  });

  test('parse all games', () async {
      //arrange
      var sut = await DataImport.create(da);
      await sut.importArchives();
      await sut.importGamesInAllArchives();
      //act
      await sut.parseAllGames();
      //assert
    }, skip: true);

  test('should parse a date and time', () async {
    //arrange
    var dateTimeString = '2024.07.21 18:28:44';
    //act
    var dateTime = DataImport.parseDate(dateTimeString);
    //assert
    expect(dateTime.day, equals(21));
    expect(dateTime.month, equals(7));
    expect(dateTime.year, equals(2024));
    expect(dateTime.hour, equals(18));
    expect(dateTime.minute,equals(28));
  });
}