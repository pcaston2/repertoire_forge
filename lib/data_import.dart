import 'package:dartchess/dartchess.dart' hide Move;
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:repertoire_forge/chess_helper.dart';
import 'data_access.dart';
import 'chess_dot_com_client.dart';
import 'database.dart' hide Position;
import 'eco_codes.dart';

class DataImport {
  DataAccess dataAccess;
  ChessDotComClient client;
  EcoCodes codes = EcoCodes();

  DataImport._create({required this.dataAccess, required this.client});

  static Future<DataImport> create(DataAccess dataAccess) async {
    var user = await dataAccess.user;
    var client = ChessDotComClient(user.username);
    return DataImport._create(dataAccess: dataAccess, client: client);
  }

  static DateTime parseDate(String date) {
    var formatter = DateFormat('yyyy.MM.dd HH:mm:ss');
    return formatter.parse(date);
  }

  Future<int> getPendingImportGameCount() async {
    await for(var _ in importArchives());
    var archives = await dataAccess.archives;
    for (var a in archives) {
      await importGamesInArchive(a.name);
    }
    return await dataAccess.getUnimportedGameCount();
  }

  static String prettyDate(DateTime date) {
    var formatter = DateFormat("MMM. d, ''yy, h:mm a");
    return formatter.format(date);
  }

  Stream<Archive> importArchives() async* {
      var archives = await client.getArchives();
      for (var a in archives) {
        var archive = await dataAccess.getOrAddArchive(a);
        yield archive;
      }
  }

  Future<void> importGamesInArchive(String archiveName) async {
    var archive = await dataAccess.getOrAddArchive(archiveName);
    var hash = await client.getArchiveHash(archiveName);
    if (!archive.imported || archive.hash != hash) {
      await dataAccess.transaction(() async {
        var games = await client.getGamesInArchive(archiveName);
        for (var g in games) {
          await dataAccess.getOrAddGame(g);
        }
        await dataAccess.setArchiveImported(archiveName, hash);
      });
    }
  }

  Stream<Archive> importGamesInAllArchives() async* {
    var archives = await dataAccess.archives;
    for (var a in archives) {
      await importGamesInArchive(a.name);
      yield a;
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

      var event = pgnGame.headers["Event"];
      var site = pgnGame.headers["Site"];
      var round = pgnGame.headers["Round"];
      var white = pgnGame.headers["White"];
      var black = pgnGame.headers["Black"];
      var currentPosition = pgnGame.headers["CurrentPosition"];
      var timezone = pgnGame.headers["Timezone"];
      var eco = pgnGame.headers["ECO"];
      var ecoUrl = pgnGame.headers["ECOUrl"];
      var date = pgnGame.headers["Date"];
      var whiteElo = int.parse(pgnGame.headers["WhiteElo"]!);
      var blackElo = int.parse(pgnGame.headers["BlackElo"]!);
      var timeControl = pgnGame.headers["TimeControl"];
      var termination = pgnGame.headers["Termination"];
      var startTime = pgnGame.headers["StartTime"];
      var endDate = pgnGame.headers["EndDate"];
      var endTime = pgnGame.headers["EndTime"];
      var link = pgnGame.headers["Link"];

      var startDateTime = parseDate("$date $startTime");
      var endDateTime = parseDate("$endDate $endTime");
      if (white == user) {
        isWhite = true;
      } else if (black == user) {
        isWhite = false;
      }
      if (isWhite == null) {
        return false;
      }
      var opponentRating = (isWhite ? blackElo : whiteElo);
      var opponentUser = (isWhite ? black : white);

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
      var openingName = "Irregular opening";
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
        var ecoCode = codes.getFromFen(ChessHelper.stripMoveClockInfoFromFEN(fen));
        if (ecoCode != null) {
          openingName = ecoCode.name;
        }
        var position = await dataAccess.getOrAddPosition(ChessHelper.stripMoveClockInfoFromFEN(fen));
        await dataAccess.addGamePosition(game, position, moveCount, !myMove);
        var moveEntry = await dataAccess.getOrAddMove(previousPosition.fen, moveNode.san, position.fen);
        await dataAccess.addGameMove(game, moveEntry, moveCount, myMove);
        moveCount++;
        previousPosition = position;
      }
      var updatedGame = game.copyWith(
        isWhite: Value<bool?>(isWhite),
        score: Value<double?>(score),
        imported: true,
        opponentUser: Value<String?>(opponentUser),
        oppenentRating: Value<int?>(opponentRating),
        event: Value<String?>(event),
        site: Value<String?>(site),
        date: Value<DateTime?>(startDateTime),
        round: Value<String?>(round),
        white: Value<String?>(white),
        black: Value<String?>(black),
        result: Value<String?>(result),
        currentPosition: Value<String?>(currentPosition),
        timezone: Value<String?>(timezone),
        eco: Value<String?>(eco),
        ecoUrl: Value<String?>(ecoUrl),
        utcDate: Value<DateTime?>(startDateTime),
        whiteElo: Value<int?>(whiteElo),
        blackElo: Value<int?>(blackElo),
        timeControl: Value<String?>(timeControl),
        termination: Value<String?>(termination),
        startDate: Value<DateTime?>(startDateTime),
        endDate: Value<DateTime?>(endDateTime),
        link: Value<String?>(link),
        openingName: Value<String?>(openingName),
      );
      await dataAccess.setGame(updatedGame);
    });
    return true;
  }

  Stream<Game> parseAllGames() async* {
    var games = await dataAccess.getGamesToImport();
    for(var game in games) {
      if (await parseGame(game.uuid)) {
        yield game;
      }
    }
  }

  Stream<Game> parseGamesByArchive(String archiveName) async* {
    var games = await dataAccess.getGamesByArchiveToImport(archiveName);
    for (var game in games) {
      await parseGame(game.uuid);
      yield game;
    }
  }
}