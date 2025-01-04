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
}