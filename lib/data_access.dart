import 'package:drift/src/runtime/query_builder/query_builder.dart';

import 'database.dart';

class DataAccess {
  final AppDatabase _database;
  DataAccess(this._database);

  Future<User> addUser(String username) async {
    return await _database.into(_database.users).insertReturning(UsersCompanion.insert(username: username));
  }

  Future<User?> get user async {
    return _database.select(_database.users).getSingleOrNull();
  }

  Future<bool> get hasUser async {
    return (await user) != null;
  }

  Future<List<Archive>> get archives async {
    return await _database.select(_database.archives).get();
  }

  Future<Archive> addArchive(String archiveName) async {
    return await _database.into(_database.archives).insertReturning(ArchivesCompanion.insert(user: (await user)!.username, name: archiveName, hash: "", imported: false));
  }

  Future<Game> addGame(Game game) async {
    return await _database.into(_database.games).insertReturning(game);
  }

  Future<Game> getGame(String gameId) async {
    return await (_database.select(_database.games)..where((g) => g.uuid.equals(gameId))).getSingle();
  }

  Future<Position> getOrAddPosition(String fen) async {
    var pos = await getPosition(fen);
    if (pos == null) {
      return await (_database.into(_database.positions).insertReturning(PositionsCompanion.insert(fen: fen)));
    } else {
      return pos;
    }
  }

  Future<Position?> getPosition(String fen) async {
    return await (_database.select(_database.positions)..where((p) => p.fen.equals(fen))).getSingleOrNull();
  }

  Future<GamePosition> addGamePosition(Game game, Position position, int moveNumber) async {
    return await(_database.into(_database.gamePositions).insertReturning(GamePositionsCompanion.insert(game: game.uuid, position: position.fen, moveNumber: moveNumber)));
  }

  Future<List<Game>> getGames() async {
    return await _database.select(_database.games).get();
  }

  Future<List<Game>> getGamesByArchive(String archiveName) async {
    return await (_database.select(_database.games)..where((g) => g.archive.equals(archiveName))).get();
  }

  Future<Move> addMove(String fromFen, String move, String toFen) async {
    return await (_database.into(_database.moves).insertReturning(MovesCompanion.insert(fromFen: fromFen, move: move, toFen: toFen)));
  }
}