
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/data_access.dart';
import 'package:repertoire_forge/database.dart';

void main() {
  AppDatabase? database;

  setUp(() {
    database = AppDatabase(DatabaseConnection(
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
}