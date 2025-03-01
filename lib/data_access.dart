import 'package:dartchess/dartchess.dart' as chess;
import 'package:drift/drift.dart';
import 'package:repertoire_forge/repertoire_explorer.dart';


import 'chess_helper.dart';
import 'database.dart';

class DataAccess {
  final AppDatabase _database;
  DataAccess(this._database);

  setUser(String username) async {
    var existingUser = await user;
    await _database.update(_database.users).write(existingUser.copyWith(username: username));
  }

  Future<T> transaction<T>(Future<T> Function() action,
      {bool requireNew = false}) async {
    return _database.transaction(action, requireNew: requireNew);
  }

  Future<User> get user async {
    var user = await _database.select(_database.users).getSingleOrNull();
    if (user == null) {
      return await _database.into(_database.users).insertReturning(UsersCompanion.insert(username: ""));
    } else {
      return user;
    }
  }

  Future<List<Archive>> get archives async {
    return await _database.select(_database.archives).get();
  }

  Future<Archive?> getArchive(String archiveName) async {
    return await (_database.select(_database.archives)..where((a) => a.name.equals(archiveName))).getSingleOrNull();
  }

  Future<Archive> getOrAddArchive(String archiveName) async {
    var existingArchive = await getArchive(archiveName);
    if (existingArchive != null) {
      return existingArchive;
    } else {
      return await _database.into(_database.archives).insertReturning(ArchivesCompanion.insert(user: (await user).id, name: archiveName, hash: "", imported: false));
    }
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

  Future<GamePosition> addGamePosition(Game game, Position position, int moveNumber, bool myMove) async {
    return await(_database.into(_database.gamePositions).insertReturning(GamePositionsCompanion.insert(game: game.uuid, position: position.fen, moveNumber: moveNumber, myMove: myMove)));
  }

  Future<List<Game>> getGames() async {
    return await _database.select(_database.games).get();
  }

  Future<List<Game>> getGamesToImport() async {
    return await (_database.select(_database.games)..where((g) => g.imported.not())).get();
  }

  Future<List<Game>> getGamesByArchive(String archiveName) async {
    return await (_database.select(_database.games)..where((g) => g.archive.equals(archiveName))).get();
  }

  Future<List<Game>> getGamesByArchiveToImport(String archiveName) async {
    return await (_database.select(_database.games)..where((g) => Expression.and([g.archive.equals(archiveName),g.imported.not()]))).get();
  }

  Future<Move?> getMove(String fromFen, String move) async {
    return await (_database.select(_database.moves)..where((m) => Expression.and([m.fromFen.equals(fromFen), m.move.equals(move)]))).getSingleOrNull();
  }

  Future<Move> getOrAddMove(String fromFen, String move, String toFen) async {
    var moveEntry = await getMove(fromFen, move);
    if (moveEntry == null) {
      await getOrAddPosition(fromFen);
      await getOrAddPosition(toFen);
      return await (_database.into(_database.moves).insertReturning(MovesCompanion.insert(fromFen: fromFen, move: move, toFen: toFen)));
    } else {
      return moveEntry;
    }
  }


  Future<GameMove> addGameMove(Game game, Move move, int moveNumber, bool myMove) async {
    return await (_database.into(_database.gameMoves).insertReturning(GameMovesCompanion.insert(fromFen: move.fromFen, move: move.move, game: game.uuid, moveNumber: moveNumber, myMove: myMove)));
  }

  Future<Repertoire> getRepertoire(int repertoire) async {
    return await (_database.select(_database.repertoires)..where((r) => r.id.equals(repertoire))).getSingle();
  }

  Future<Repertoire?> getUserRepertoire({bool isWhite = true}) async {
    var currentUser = await user;
    var repertoire = (isWhite? currentUser.whiteRepertoire : currentUser.blackRepertoire);
    if (repertoire == null) {
      return null;
    } else {
      return getRepertoire(repertoire);
    }
  }

  Future<Repertoire> createRepertoire(bool isWhite, String repertoireName) async {
    return await(_database.into(_database.repertoires).insertReturning(RepertoiresCompanion.insert(name: repertoireName)));
  }

  setUserRepertoire(int repertoireId, {bool isWhite = true}) async {
    var currentUser = await user;
    await _database.update(_database.users).write((
        isWhite ?
        currentUser.copyWith(whiteRepertoire: Value(repertoireId)) :
        currentUser.copyWith(blackRepertoire: Value(repertoireId))
    ));
  }

  Future<RepertoireMove?> getRepertoireMove(String fromFen, String move, int repertoire) async {
    return await (_database.select(_database.repertoireMoves)..where((m) => Expression.and([m.fromFen.equals(fromFen),m.move.equals(move), m.repertoire.equals(repertoire)]))).getSingleOrNull();
  }

  Future<RepertoireMove> getOrAddRepertoireMove(String fromFen, String move, int repertoire) async {
    var repertoireMove = await getRepertoireMove(fromFen, move, repertoire);
    if (repertoireMove != null) {
      return repertoireMove;
    } else {
      return addRepertoireMove(fromFen, move, repertoire);
    }
  }

  Future<RepertoireMove> addRepertoireMove(String fromFen, String move, int repertoire) async {
    return await _database.into(_database.repertoireMoves).insertReturning(RepertoireMovesCompanion.insert(fromFen: fromFen, move: move, repertoire: repertoire));
  }

  Future<List<RepertoireMove>> getRepertoireMoves(String fromFen, int repertoire) async {
    return (_database.select(_database.repertoireMoves)..where((r) => Expression.and([r.fromFen.equals(fromFen), r.repertoire.equals(repertoire)]))).get();
  }

  Future<List<GameMove>> getGameMoves(String fromFen) {
    return (_database.select(_database.gameMoves)..where((m) => m.fromFen.equals(fromFen))).get();
  }

  Future<void> setArchiveImported(String archiveName, String hash) async {
    var archive = (await getArchive(archiveName))!;
    await _database.update(_database.archives).replace(archive.copyWith(hash: hash, imported: true));
  }

  Future<void> setGameImported(String gameId) async {
    var game = await getGame(gameId);
    await _database.update(_database.games).replace(game.copyWith(imported: true));
  }


  Future<void> setIsWhite(String gameId, bool isWhite) async {
    var game = await getGame(gameId);
    await _database.update(_database.games).replace(game.copyWith(isWhite: Value(isWhite)));
  }

  Future<void> setGameScore(String gameId, double score) async {
    var game = await getGame(gameId);
    await _database.update(_database.games).replace(game.copyWith(score: Value<double?>(score)));
  }


  Future<void> setGame(Game updatedGame) async {
    await _database.update(_database.games).replace(updatedGame);
  }


  Future<void> setGameReviewed(String gameId) async {
    var game = await getGame(gameId);
    await _database.update(_database.games).replace(game.copyWith(reviewed: true));
  }

  Future<List<MoveStat>> getMoveStats(String fen, int repertoire, bool myMove) async {
    var repoMoves = await getRepertoireMoves(fen, repertoire);
    var query = _database.selectOnly(_database.gameMoves)
      .join([
          innerJoin(_database.games, _database.games.uuid.equalsExp(_database.gameMoves.game)),
        ])
      ..addColumns([_database.gameMoves.move, countAll(), _database.games.score.avg()])
      ..where((_database.gameMoves.fromFen.equals(fen)))
      ..where((myMove ? _database.gameMoves.myMove : _database.gameMoves.myMove.not()))
      ..groupBy([_database.gameMoves.move]);
    var moveScores = await query.get();
    var moveStats = <MoveStat>[];
    for (var m in moveScores) {
      var entries = m.rawData.data.entries.toList();
      String move = entries[0].value;
      moveStats.add(MoveStat(entries[0].value, entries[1].value, entries[2].value, repoMoves.any((r) => r.move == move)));
      repoMoves.removeWhere((r) => r.move == move);
    }
    for (var r in repoMoves) {
      moveStats.add(MoveStat(r.move, 0, 1, true));
    }
    return moveStats;
  }

  Future<String> exportRepertoire(int repertoire, bool myMove) async {
    var root = chess.PgnNode();
    var initialFen = ChessHelper.stripMoveClockInfoFromFEN(chess.Chess.initial.fen);
    root.children.addAll(await getRepositoryChildren(repertoire, initialFen, myMove));
    var game = chess.PgnGame(headers: <String, String>{}, moves: root, comments: []);
    return game.makePgn();
  }

  Future<void> importRepertoire(int repertoire, String pgn) async {
    await transaction(() async {
      var pgnGame = chess.PgnGame.parsePgn(pgn);
      chess.Position startingPosition = chess.PgnGame.startingPosition(
          pgnGame.headers);
      await getOrAddPosition(
          ChessHelper.stripMoveClockInfoFromFEN(startingPosition.fen));
      for (var m in pgnGame.moves.children) {
        await importChildren(repertoire, m, startingPosition);
      }
    });
  }

  Future<void> importChildren(int repertoire, chess.PgnChildNode move, chess.Position position) async {
    var currentMove = position.parseSan(move.data.san);
    var nextPosition = position.play(currentMove!);
    await getOrAddMove(ChessHelper.stripMoveClockInfoFromFEN(position.fen), move.data.san, ChessHelper.stripMoveClockInfoFromFEN(nextPosition.fen));
    await getOrAddRepertoireMove(ChessHelper.stripMoveClockInfoFromFEN(position.fen), move.data.san, repertoire);
    for (var m in move.children) {
      await importChildren(repertoire, m, nextPosition);
    }
  }

  Future<List<chess.PgnChildNode>> getRepositoryChildren(int repertoire, String fen, bool myMove) async {
    var moveStats = (await getMoveStats(fen, repertoire, myMove)).where((m) => m.repo).toList()..sort((a,b) => b.count.compareTo(a.count));
    var children = <chess.PgnChildNode>[];
    for (var m in moveStats) {
      var child = chess.PgnChildNode(chess.PgnNodeData(san: m.move));
      var move = await getMove(fen, m.move);
      child.children.addAll(await getRepositoryChildren(repertoire, move!.toFen, !myMove));
      children.add(child);
    }
    return children;
  }

  removeRepertoireMove(int repertoire, String fen, String move) async {
    var repertoireMove = await getRepertoireMove(fen, move, repertoire);
    if (repertoireMove != null) {
      await _database.delete(_database.repertoireMoves).delete(repertoireMove);
    }
  }

  Future<GameRepertoireComparison?> generateGameComparison(int repertoire, String game) async {
    var gameMoves = await (_database
        .select(_database.gameMoves)
      ..where((m) => m.game.equals(game))
      ..orderBy([(m) => OrderingTerm(expression: m.moveNumber)])).get();
    if (gameMoves.isEmpty) {
      return null;
    }
    for (var g in gameMoves) {
      var potentialMoves = await getRepertoireMoves(g.fromFen, repertoire);
      if (potentialMoves.isEmpty) {
        return GameRepertoireComparison(
            game: game,
            fromFen: g.fromFen,
            move: g.move,
            deviated: false,
            moveNumber: g.moveNumber,
            myMove: g.myMove,
            reviewed: false);
      } else {
        if (potentialMoves.any((r) => r.move == (g.move))) {
          continue;
        } else {
          return GameRepertoireComparison(game: game,
              fromFen: g.fromFen,
              move: g.move,
              deviated: true,
              moveNumber: g.moveNumber,
              myMove: g.myMove,
              reviewed: false);
        }
      }
    }
    var last = gameMoves.last;
    return GameRepertoireComparison(game: game,
        fromFen: last.fromFen,
        move: last.move,
        deviated: false,
        moveNumber: last.moveNumber,
        myMove: last.myMove,
        reviewed: false);
  }

  Future<GameRepertoireComparison?> getOrCreateGameComparison(int repertoire, String game) async {
    var comparison = await getGameComparison(game);
    if (comparison != null) {
      return comparison;
    } else {
      var comparison = await generateGameComparison(repertoire, game);
      await transaction(() async {
        if (comparison != null) {
          await addOrUpdateGameComparison(comparison);
        }
        await setGameReviewed(game);
      });
      return comparison;
    }
  }

  Future<void> addOrUpdateGameComparison(GameRepertoireComparison comparison) async {
    await _database.into(_database.gameRepertoireComparisons).insertOnConflictUpdate(comparison);
  }

  Future<GameRepertoireComparison?> getGameComparison(String game) async {
    return await (_database.select(_database.gameRepertoireComparisons)..where((c) => c.game.equals(game))).getSingleOrNull();
  }

  Future<Repertoire> getOrCreateUserRepertoire({bool isWhite = true}) async {
    var repertoire = await getUserRepertoire(isWhite: isWhite);
    repertoire ??= await createRepertoire(isWhite, (isWhite ? "White" : "Black"));
    setUserRepertoire(repertoire.id, isWhite: isWhite);
    return repertoire;
  }

  Future<List<Repertoire>> getRepertoires() async {
    return await (_database.select(_database.repertoires)).get();
  }

  Future<Game?> getOrAddGame(Game game) async {
    var gameEntry = await (_database.select(_database.games)..where((g) => g.uuid.equals(game.uuid))).getSingleOrNull();
    if (gameEntry != null) {
      return gameEntry;
    } else {
      return await addGame(game);
    }
  }

  Future<void> markAllGamesCompared() async {
    await _database.update(_database.games).write(GamesCompanion(reviewed: Value(true)));
  }

  Future<void> compareAllGames(int whiteRepertoireId, int blackRepertoireId) async {
    var games = await (_database.select(_database.games)..where((g) => Expression.and([g.reviewed.not(), g.imported, g.isWhite.isNotNull()]))).get();
    for (var g in games) {
      await getOrCreateGameComparison((g.isWhite! ? whiteRepertoireId : blackRepertoireId), g.uuid);
    }
  }

  Future<List<ComparisonAndGameEntry>> getUnreviewedComparisons() async {
    var query = await (_database
        .select(_database.gameRepertoireComparisons)
        .join([innerJoin(_database.games, _database.games.uuid.equalsExp(_database.gameRepertoireComparisons.game))])
      ..where(_database.gameRepertoireComparisons.reviewed.not()));
    return query.map((row) => ComparisonAndGameEntry(row.readTable(_database.games), row.readTable(_database.gameRepertoireComparisons))).get();
  }

}

class MoveStat {
  late String move;
  late int count;
  late double score;
  late bool repo;

  MoveStat(this.move, this.count, this.score, this.repo);

  @override
  String toString() {
    return "$move: $count (${(score*100).round()}%))";
  }
}