
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';



class Archives extends Table {
  TextColumn get name => text()();
  TextColumn get hash => text()();
  BoolColumn get imported => boolean()();
  late final user = text().references(Users, #username)();

  @override
  Set<Column<Object>> get primaryKey => {name};
}

class Users extends Table {
  TextColumn get username => text()();

  @override
  Set<Column<Object>> get primaryKey => {username};
}

class Games extends Table {
  TextColumn get uuid => text()();
  TextColumn get pgn => text()();
  BoolColumn get imported => boolean()();
  late final archive = text().references(Archives, #name)();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

class Positions extends Table {
  TextColumn get fen => text()();

  @override
  Set<Column<Object>> get primaryKey => {fen};
}

class GamePositions extends Table {
  late final game = text().references(Games, #uuid)();
  late final position = text().references(Positions, #fen)();
  IntColumn get moveCount => integer()();
}

//class Moves extends Table {
  //late final fromFen = text().references(Positions, #fen);
  //TextColumn get move => text()();
  //late final toFen = text().references(Positions, #fen);

  //@override
  //Set<Column<Object>> get primaryKey => {fromFen, move, toFen};
//}

@DriftDatabase(tables: [Games, Archives, Users, Positions, GamePositions])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        if (details.wasCreated) {
          // ...
        }
        await customStatement('PRAGMA foreign_keys = ON');
      }
    );
  }
}