import 'package:chess/chess.dart';
import 'package:repertoire_forge/database.dart';
import 'package:repertoire_forge/chess_helper.dart';
import 'data_access.dart';
import 'chess_dot_com_client.dart';

class DataImport {
  DataAccess dataAccess;
  ChessDotComClient client;

  DataImport._create({required this.dataAccess, required this.client});

  static Future<DataImport> create(DataAccess dataAccess) async {
    if (!await dataAccess.hasUser) {
      throw ArgumentError("Username must be set before initializing data import");
    }
    var user = await dataAccess.user;
    var client = ChessDotComClient(user!.username);
    return DataImport._create(dataAccess: dataAccess, client: client);
  }

  importArchives() async {
    var archives = await client.getArchives();
    for (var a in archives) {
      await dataAccess.addArchive(a);
    }
  }

  importGamesInArchive(String archiveName) async {
    var games = await client.getGamesInArchive(archiveName);
    for (var g in games) {
      await dataAccess.addGame(g);
    }
  }

  importAllGames() async {
    var archives = await dataAccess.archives;
    for (var a in archives) {
      await importGamesInArchive(a.name);
    }
  }

  parseGame(String gameId) async {
    var game = await dataAccess.getGame(gameId);
    var chessPgn = Chess();
    chessPgn.load_pgn(game.pgn);
    var chess = Chess();
    var initialFen = chess.fen;
    var initialPosition = await dataAccess.getOrAddPosition(ChessHelper.StripMoveInfoFromFEN(initialFen));
    var previousPosition = initialPosition;
    await dataAccess.addGamePosition(game, initialPosition, chess.move_number);
    for (var san in chessPgn.san_moves()) {
      var moves = san!.split(" ").skip(1);
      for (var move in moves) {
        chess.move(move);
        var fen = chess.fen;
        var position = await dataAccess.getOrAddPosition(
            ChessHelper.StripMoveInfoFromFEN(fen));
        var moveEntry = await dataAccess.addMove(previousPosition.fen, move, position.fen);
        await dataAccess.addGamePosition(game, position, chess.move_number);
        previousPosition = position;
      }
    }
  }

  parseAllGames() async {
    var games = await dataAccess.getGames();
    for(var game in games) {
      await parseGame(game.uuid);
    }
  }

  parseGamesByArchive(String archiveName) async {
    var games = await dataAccess.getGamesByArchive(archiveName);
    for (var game in games) {
      await parseGame(game.uuid);
    }
  }
}