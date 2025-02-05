import 'package:dartchess/dartchess.dart' as chess;
import 'package:drift/drift.dart';
import 'package:drift/src/runtime/query_builder/query_builder.dart';
import 'package:collection/collection.dart';


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

  Future<List<Game>> getGamesByArchive(String archiveName) async {
    return await (_database.select(_database.games)..where((g) => g.archive.equals(archiveName))).get();
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

  Future<Repertoire?> getRepertoire() async {
    var repertoire = (await user).repertoire;
    if (repertoire == null) {
      return null;
    } else {
      return await (_database.select(_database.repertoires)..where((r) => r.id.equals(repertoire))).getSingle();
    }
  }

  Future<Repertoire> createRepertoire(String repertoireName) async {
    return await(_database.into(_database.repertoires).insertReturning(RepertoiresCompanion.insert(name: repertoireName)));
  }

  setRepertoire(int repertoireId) async {
    var currentUser = await user;
    await _database.update(_database.users).write(currentUser.copyWith(repertoire: Value(repertoireId)));
  }

  Future<RepertoireMove> getOrAddRepertoireMove(String fromFen, String move, int repertoire) async {
    var repertoire = (await user).repertoire!;
    var repertoireMove = await (_database.select(_database.repertoireMoves)..where((m) => Expression.and([m.fromFen.equals(fromFen),m.move.equals(move), m.repertoire.equals(repertoire)]))).getSingleOrNull();
    if (repertoireMove != null) {
      return repertoireMove;
    } else {
      return await _database.into(_database.repertoireMoves).insertReturning(RepertoireMovesCompanion.insert(fromFen: fromFen, move: move, repertoire: repertoire));
    }
  }

  Future<List<RepertoireMove>> getRepertoireMoves(String fromFen, int repertoire) async {
    return (_database.select(_database.repertoireMoves)..where((r) => r.fromFen.equals(fromFen))).get();
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

  Future<void> setGameScore(String gameId, double score) async {
    var game = await getGame(gameId);
    await _database.update(_database.games).replace(game.copyWith(score: score));
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
    root.children.addAll(await getChildren(repertoire, initialFen, myMove));
    var game = chess.PgnGame(headers: <String, String>{}, moves: root, comments: []);
    return game.makePgn();
  }

  Future<void> importRepertoire(int repertoire, String pgn) async {
    await transaction(() async {
      var pgnGame = chess.PgnGame.parsePgn(pgn);
      chess.Position startingPosition = chess.PgnGame.startingPosition(pgnGame.headers);
      getOrAddPosition(ChessHelper.stripMoveClockInfoFromFEN(startingPosition.fen));
      for (var m in pgnGame.moves.children) {
        importChildren(repertoire, m, startingPosition);
      }

        // var move = chessPosition.parseSan(moveNode.san)!;
        // chessPosition = chessPosition.play(move);
        // var fen = chessPosition.fen;
        // var position = await dataAccess.getOrAddPosition(ChessHelper.stripMoveClockInfoFromFEN(fen));
        // await dataAccess.addGamePosition(game, position, moveCount, !myMove);
        // var moveEntry = await dataAccess.getOrAddMove(previousPosition.fen, moveNode.san, position.fen);
        // await dataAccess.addGameMove(game, moveEntry, moveCount, myMove);
        // previousPosition = position;
    });
  }

  Future<void> importChildren(int repertoire, chess.PgnChildNode move, chess.Position position) async {
    var currentMove = position.parseSan(move.data.san);
    var nextPosition = position.play(currentMove!);
    await getOrAddMove(ChessHelper.stripMoveClockInfoFromFEN(position.fen), move.data.san, ChessHelper.stripMoveClockInfoFromFEN(nextPosition.fen));
    await getOrAddRepertoireMove(ChessHelper.stripMoveClockInfoFromFEN(position.fen), move.data.san, repertoire);
    for (var m in move.children) {
      importChildren(repertoire, m, nextPosition);
    }
  }

  Future<List<chess.PgnChildNode>> getChildren(int repertoire, String fen, bool myMove) async {
    var moveStats = (await getMoveStats(fen, repertoire, myMove)).where((m) => m.repo).toList()..sort((a,b) => b.count.compareTo(a.count));
    var children = <chess.PgnChildNode>[];
    for (var m in moveStats) {
      var child = chess.PgnChildNode(chess.PgnNodeData(san: m.move));
      var move = await getMove(fen, m.move);
      child.children.addAll(await getChildren(repertoire, move!.toFen, !myMove));
      children.add(child);
    }
    return children;
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