
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
part 'database.g.dart';



class Archives extends Table {
  TextColumn get name => text()();
  TextColumn get hash => text()();
  BoolColumn get imported => boolean()();
  IntColumn get user => integer().references(Users, #id)();
  @override
  Set<Column<Object>> get primaryKey => {name};
}

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text()();
  @ReferenceName("white")
  IntColumn get whiteRepertoire => integer().nullable().references(Repertoires, #id)();
  @ReferenceName("black")
  IntColumn get blackRepertoire => integer().nullable().references(Repertoires, #id)();
}

class Games extends Table {
  TextColumn get uuid => text()();
  TextColumn get pgn => text()();
  BoolColumn get imported => boolean()();
  BoolColumn get reviewed => boolean()();
  RealColumn get score => real()();
  TextColumn get archive => text().references(Archives, #name)();
  BoolColumn get isWhite => boolean().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {uuid};
}

class Positions extends Table {
  TextColumn get fen => text()();

  @override
  Set<Column<Object>> get primaryKey => {fen};
}

class GamePositions extends Table {
  TextColumn get game => text().references(Games, #uuid)();
  TextColumn get position => text().references(Positions, #fen)();
  IntColumn get moveNumber => integer()();
  BoolColumn get myMove => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {position, game, moveNumber};
}

class Moves extends Table {
  @ReferenceName("fromFens")
  TextColumn get fromFen => text().references(Positions, #fen)();
  TextColumn get move => text()();
  @ReferenceName("toFens")
  TextColumn get toFen => text().references(Positions, #fen)();

  @override
  Set<Column<Object>> get primaryKey => {fromFen, move};
}

class GameRepertoireComparisons extends Table {
  TextColumn get game => text()();
  TextColumn get fromFen => text()();
  TextColumn get move => text()();
  IntColumn get moveNumber => integer()();
  BoolColumn get myMove => boolean()();
  BoolColumn get deviated => boolean()();
  BoolColumn get reviewed => boolean()();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (game, from_fen, move, move_number) REFERENCES game_moves (game, from_fen, move, move_number)',
  ];


  @override
  Set<Column<Object>> get primaryKey => {game};
}

class GameMoves extends Table {
  TextColumn get fromFen => text()();
  TextColumn get move => text()();
  TextColumn get game => text().references(Games, #uuid)();
  BoolColumn get myMove => boolean()();
  IntColumn get moveNumber => integer()();

  @override
  Set<Column<Object>> get primaryKey => {fromFen, move, game, moveNumber};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (from_fen, move) REFERENCES moves (from_fen, move)',
  ];
}

class RepertoireMoves extends Table {
  TextColumn get fromFen => text()();
  TextColumn get move => text()();
  IntColumn get repertoire => integer().references(Repertoires, #id)();

  @override
  Set<Column<Object>> get primaryKey => {fromFen, move, repertoire};

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (from_fen, move) REFERENCES moves (from_fen, move)',
  ];
}

class Repertoires extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

@DriftDatabase(tables: [Games, Archives, Users, Repertoires, Positions, GamePositions, Moves, GameMoves, RepertoireMoves, GameRepertoireComparisons])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.configurable(super.e);
  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'repertoire_forge.sqlite'));

      return NativeDatabase.createInBackground(file);
    });
  }

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