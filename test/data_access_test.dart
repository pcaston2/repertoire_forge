
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/data_access.dart';
import 'package:repertoire_forge/data_import.dart';
import 'package:repertoire_forge/database.dart';
import 'package:repertoire_forge/repertoire_explorer.dart';

void main() {
  AppDatabase? database;

  setUp(() {
    database = AppDatabase.configurable(drift.DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
  });

  tearDown(() async {
    await database?.close();
  });

  String username = 'test user';
  String archiveName = 'https://api.chess.com/pub/player/pcaston2/games/2016/04';
  String initialPosition = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
  String initialMove = "e4";
  String nextPosition = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -";
  String alternateMove = "Nf3";
  String alternatePosition = "rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq -";

  test('sets user', () async {
    //arrange
    var sut = DataAccess(database!);
    //act
    await sut.setUser(username);
    var user = await sut.user;
    //assert
    expect(user.username, equals(username));
  });

  test('add archive', () async {
    //arrange
    var sut = DataAccess(database!);
    //act
    await sut.setUser(username);
    await sut.getOrAddArchive(archiveName);
    var archives = await sut.archives;
    //assert
    expect(archives, hasLength(1));
    expect(archives.single.name, archiveName);
  });

  test ('insert position', () async {
    //arrange
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
    var sut = DataAccess(database!);
    //act
    var pos = await sut.getOrAddPosition(fen);
    //
    expect(pos.fen, equals(fen));
  });

  test ('get existing position', () async {
    //arrange
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
    var sut = DataAccess(database!);
    await sut.getOrAddPosition(fen);
    //act
    var pos = await sut.getPosition(fen);
    //assert
    expect(pos, isNotNull);
    expect(pos!.fen, equals(fen));
  });

  test ('fail to get if not inserted position', () async {
    //arrange
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
    var sut = DataAccess(database!);
    //act
    var pos = await sut.getPosition(fen);
    //
    expect(pos, equals(null));
  });

  test('insert move', () async {
    //arrange
    var sut = DataAccess(database!);
    var fromFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
    var toFen = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3";
    var move = "e4";
    //act
    var result = await sut.getOrAddMove(fromFen, move, toFen);
    //assert
    expect(result, isNotNull);
  });


  test('get info about moves', () async {
    //arrange
    var sut = DataAccess(database!);
    await sut.setUser("pcaston2");
    var di = await DataImport.create(sut);
    var explorer = await RepertoireExplorer.create(sut);
    await di.importGamesInArchive(archiveName);
    await di.parseGamesByArchive(archiveName);
    await explorer.addMove(initialPosition, initialMove, nextPosition);
    await explorer.addMove(initialPosition, alternateMove, alternatePosition);
    var repertoireId = (await explorer.repertoire).id;
    //act
    var result = await sut.getMoveStats(initialPosition, repertoireId, true);
    //assert
    expect(result.where((m) => m.move == initialMove).single.count, 1);
    expect(result.where((m) => m.move == alternateMove).single.count, 0);
  });
}