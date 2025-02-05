import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/data_access.dart';
import 'package:repertoire_forge/database.dart';
import 'package:repertoire_forge/repertoire_explorer.dart';

void main() {
  late DataAccess da;
  late AppDatabase database;

  String repertoireName = 'e4';
  String initialPosition = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
  String move = "e4";
  String alternateMove = "d4";
  String secondPosition = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -";
  String alternatePosition = "rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3";
  String blacksMove = "e5";
  String blacksPosition = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6";

  setUp(() {
    database = AppDatabase.configurable(DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
    da = DataAccess(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('add default repertoire', () async {
    //arrange
    var sut = await RepertoireExplorer.create(da);
    //act
    var repertoire = await sut.repertoire;
    //assert
    expect(repertoire.name, equals("Default"));
  });

  test('add specific repertoire', () async {
    //arrange
    var sut = await RepertoireExplorer.create(da);
    //act
    var repertoire = await sut.createRepertoire(repertoireName);
    //assert
    expect(repertoire.name, equals(repertoireName));
  });

  test('set repertoire', () async {
    //arrange
    var sut = await RepertoireExplorer.create(da);
    //act
    var currentRepertoire = await sut.repertoire;

    //assert
    expect(currentRepertoire.name, equals("Default"));
  });

  test('get moves', () async {
    //arrange
    var sut = await RepertoireExplorer.create(da);
    await sut.repertoire;
    await sut.addMove(initialPosition, move, secondPosition);
    //act
    var result = await sut.getMoves(initialPosition);
    //assert
    expect(result.length, equals(1));
    expect(result.single.move, equals(move));
  });

  test('export repertoire', () async {
    //arrange
    var expectedPgn = "1. e4 ( 1. d4 ) 1... e5 *\n";
    await da.getOrAddArchive("1");
    var game = await da.addGame(Game(uuid: "gameId", pgn: "", imported: true, score: 0.0, archive: "1"));
    var commonMove = await da.getOrAddMove(initialPosition, move, secondPosition);
    await da.addGameMove(game, commonMove, 1, true);
    var sut = await RepertoireExplorer.create(da);
    await sut.addMove(initialPosition, move, secondPosition);
    await sut.addMove(initialPosition, alternateMove, alternatePosition);
    await sut.addMove(secondPosition, blacksMove, blacksPosition);
    //act
    var result = await sut.exportRepertoire(true);
    //assert
    expect(result, equals(expectedPgn));
  });

  test('import repertoire', () async {
    //arrange
    var importedPgn = "1. e4 ( 1. d4 ) 1... e5 *\n";
    var sut = await RepertoireExplorer.create(da);
    //act
    sut.importRepertoire(importedPgn);
    //assert
  });
}