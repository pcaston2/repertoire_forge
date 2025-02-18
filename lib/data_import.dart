import 'package:dartchess/dartchess.dart' hide Move;
import 'package:repertoire_forge/chess_helper.dart';
import 'data_access.dart';
import 'chess_dot_com_client.dart';

class DataImport {
  DataAccess dataAccess;
  ChessDotComClient client;

  DataImport._create({required this.dataAccess, required this.client});

  static Future<DataImport> create(DataAccess dataAccess) async {
    var user = await dataAccess.user;
    var client = ChessDotComClient(user.username);
    return DataImport._create(dataAccess: dataAccess, client: client);
  }

  Future<void> importArchives() async {
    var archives = await client.getArchives();
    for (var a in archives) {
      await dataAccess.getOrAddArchive(a);
    }
  }

  Future<void> importGamesInArchive(String archiveName) async {
    var archive = await dataAccess.getOrAddArchive(archiveName);
    var hash = await client.getArchiveHash(archiveName);
    if (archive.imported && archive.hash == hash) {
      return;
    }

    await dataAccess.transaction(() async {
      var games = await client.getGamesInArchive(archiveName);
      for (var g in games) {
        await dataAccess.addGame(g);
      }
      await dataAccess.setArchiveImported(archiveName, hash);
    });
  }

  Future<void> importAllGames() async {
    var archives = await dataAccess.archives;
    for (var a in archives) {
      await importGamesInArchive(a.name);
    }
  }

  Future<bool> parseGame(String gameId) async {
    var game = await dataAccess.getGame(gameId);
    if (game.imported) {
      return false;
    }
    await dataAccess.transaction(() async {
      var game = await dataAccess.getGame(gameId);
      var pgnGame = PgnGame.parsePgn(game.pgn);
      bool? isWhite;
      var user = (await dataAccess.user).username;
      var white = pgnGame.headers["White"];
      var black = pgnGame.headers["Black"];
      if (white == user) {
        isWhite = true;
      } else if (black == user) {
        isWhite = false;
      }
      if (isWhite == null) {
        return false;
      }
      var result = pgnGame.headers["Result"];
      var score = 0.0;
      if (result == "1-0") {
        score = (isWhite ? 1 : 0);
      } else if (result == "0-1") {
        score = (isWhite ? 0 : 1);
      } else if (result == "1/2-1/2") {
        score = 0.5;
      } else {
        return false;
      }
      Position chessPosition = PgnGame.startingPosition(pgnGame.headers);
      var initialFen = chessPosition.fen;
      var initialPosition = await dataAccess.getOrAddPosition(ChessHelper.stripMoveClockInfoFromFEN(initialFen));
      await dataAccess.addGamePosition(game, initialPosition, 0, isWhite);
      var previousPosition = initialPosition;
      var moveCount = 1;
      var moves = pgnGame.moves.mainline().toList();
      for (final moveNode in moves) {
        var whiteMove = moveCount % 2 == 1;
        var myMove = whiteMove == isWhite;
        var move = chessPosition.parseSan(moveNode.san)!;
        chessPosition = chessPosition.play(move);
        var fen = chessPosition.fen;
        var position = await dataAccess.getOrAddPosition(ChessHelper.stripMoveClockInfoFromFEN(fen));
        await dataAccess.addGamePosition(game, position, moveCount, !myMove);
        var moveEntry = await dataAccess.getOrAddMove(previousPosition.fen, moveNode.san, position.fen);
        await dataAccess.addGameMove(game, moveEntry, moveCount, myMove);
        moveCount++;
        previousPosition = position;
      }
      await dataAccess.setIsWhite(gameId, isWhite);
      await dataAccess.setGameScore(gameId, score);
      await dataAccess.setGameImported(gameId);
    });
    return true;
  }

  Future<int> parseAllGames() async {
    var games = await dataAccess.getGamesToImport();
    var parseCount = 0;
    for(var game in games) {
      var parsed = await parseGame(game.uuid);
      if (parsed) {
        parseCount++;
      }
    }
    return parseCount;
  }

  Future<int> parseGamesByArchive(String archiveName) async {
    var games = await dataAccess.getGamesByArchiveToImport(archiveName);
    var parseCount = 0;
    for (var game in games) {
      var parsed = await parseGame(game.uuid);
      if (parsed) {
        parseCount++;
      }
    }
    return parseCount;
  }
}