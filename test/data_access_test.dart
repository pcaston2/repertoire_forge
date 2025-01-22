
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/data_access.dart';
import 'package:repertoire_forge/database.dart';

void main() {
  AppDatabase? database;

  setUp(() {
    database = AppDatabase(drift.DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
  });

  tearDown(() async {
    await database?.close();
  });

  String username = 'test user';
  String archiveName = 'archive name';

  test('adds user', () async {
    //arrange
    var sut = DataAccess(database!);
    //act
    await sut.addUser(username);
    var user = await sut.user;
    //assert
    expect(await sut.hasUser, equals(true));
    expect(user!.username, equals(username));
  });

  test('add archive', () async {
    //arrange
    var sut = DataAccess(database!);
    //act
    await sut.addUser(username);
    await sut.addArchive(archiveName);
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
    await sut.getOrAddPosition(fromFen);
    await sut.getOrAddPosition(toFen);
    //act
    var result = await sut.addMove(fromFen, move, toFen);
    //assert
    expect(result, isNotNull);
  });
}