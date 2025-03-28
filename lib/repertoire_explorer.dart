import 'package:repertoire_forge/data_access.dart';
import 'database.dart';


class RepertoireExplorer {
  DataAccess dataAccess;

  RepertoireExplorer({required this.dataAccess});


  static Future<RepertoireExplorer> create(DataAccess dataAccess) async {
    return RepertoireExplorer(dataAccess: dataAccess);
  }

  Future<Repertoire?> repertoire({bool isWhite = true}) async {
    return await dataAccess.getOrCreateUserRepertoire(isWhite: isWhite);
  }

  Future<Repertoire> getOrCreateUserRepertoire({bool isWhite = true}) async {
    return await dataAccess.getOrCreateUserRepertoire(isWhite: isWhite);
  }

  Future<Repertoire> createRepertoire(String repertoireName,
      {bool isWhite = true}) async {
    return await dataAccess.createRepertoire(isWhite, repertoireName);
  }

  setRepertoire(int repertoireId) async {
    await dataAccess.setUserRepertoire(repertoireId);
  }

  Future<RepertoireMove> addMove(String fromFen, String move, String toFen,
      {bool isWhite = true}) async {
    var currentRepertoire = await getOrCreateUserRepertoire(isWhite: isWhite);
    await dataAccess.getOrAddMove(fromFen, move, toFen);
    return await dataAccess.getOrAddRepertoireMove(
        fromFen, move, currentRepertoire.id);
  }

  Future<List<MoveStat>> getMoveStats(String fen, bool myMove,
      {bool isWhite = true}) async {
    var currentRepertoire = await getOrCreateUserRepertoire(isWhite: isWhite);
    return await dataAccess.getMoveStats(fen, currentRepertoire.id, myMove);
  }

  Future<List<RepertoireMove>> getMoves(String fromFen,
      {bool isWhite = true}) async {
    var currentRepertoire = await getOrCreateUserRepertoire(isWhite: isWhite);
    return await dataAccess.getRepertoireMoves(fromFen, currentRepertoire.id);
  }

  Future<String> exportRepertoire(bool myMove, {bool isWhite = true}) async {
    var currentRepertoire = await getOrCreateUserRepertoire(isWhite: isWhite);
    return await dataAccess.exportRepertoire(currentRepertoire.id, myMove);
  }

  Future<void> importRepertoire(String pgn, {bool isWhite = true}) async {
    var currentRepertoire = await getOrCreateUserRepertoire(isWhite: isWhite);
    return await dataAccess.importRepertoire(currentRepertoire.id, pgn);
  }

  Future<void> removeMove(String fen, String move,
      {bool isWhite = true}) async {
    var currentRepertoire = await getOrCreateUserRepertoire(isWhite: isWhite);
    return await dataAccess.removeRepertoireMove(
        currentRepertoire.id, fen, move);
  }

  Future<GameRepertoireComparison?> getOrAddGameComparison(String game) async {
    var gameEntry = await dataAccess.getGame(game);
    var currentRepository = await getOrCreateUserRepertoire(
        isWhite: gameEntry.isWhite!);
    return await dataAccess.getOrCreateGameComparison(
        currentRepository.id, game);
  }

  Future<void> markAllGamesCompared() async {
    await dataAccess.markAllGamesCompared();
  }

  Stream<GameRepertoireComparison?> compareAllGames() async* {
    var whiteRepertoire = await getOrCreateUserRepertoire(isWhite: true);
    var blackRepertoire = await getOrCreateUserRepertoire(isWhite: false);
    await for(var c in dataAccess.compareAllGames(whiteRepertoire.id, blackRepertoire.id)) {
      yield c;
    }
  }

  Future<List<ComparisonAndGameEntry>> getUnreviewedComparisons() async {
    return await dataAccess.getUnreviewedComparisons();
  }

  Future<void> markAllComparisonsReviewed() async {
    return await dataAccess.markAllComparisonsReviewed();
  }

  Future<List<RecommendedReview>> getRecommendedReviews() async {
    return await dataAccess.getRecommendedReviews();
  }

  Future<List<WeightedPath>> getReviewPaths({bool isWhite = true}) async {
    var currentRepository  = await getOrCreateUserRepertoire(isWhite: isWhite);
    return await dataAccess.getReviewPaths(currentRepository.id, isWhite);
  }


}

class ComparisonAndGameEntry {
  ComparisonAndGameEntry(this.game, this.comparison);
  final Game game;
  final GameRepertoireComparison comparison;
}

class RecommendedReview {
  final String fen;
  final double score;
  final int occurrences;
  final int age;

  RecommendedReview(this.fen, this.score, this.occurrences, this.age);
}