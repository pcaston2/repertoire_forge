import 'package:repertoire_forge/data_access.dart';
import 'database.dart';


class RepertoireExplorer {
  DataAccess dataAccess;
  RepertoireExplorer._create({required this.dataAccess});


  static Future<RepertoireExplorer> create(DataAccess dataAccess) async {
    return RepertoireExplorer._create(dataAccess: dataAccess);
  }

  Future<Repertoire> get repertoire async {
    var repertoire = await dataAccess.getRepertoire();
    repertoire ??= await createRepertoire("Default");
    await setRepertoire(repertoire.id);
    return repertoire;
  }

  Future<Repertoire> createRepertoire(String repertoireName) async {
    return await dataAccess.createRepertoire(repertoireName);
  }

  setRepertoire(int repertoireId) async {
    await dataAccess.setRepertoire(repertoireId);
  }

  Future<RepertoireMove> addMove(String fromFen, String move, String toFen) async {
    var currentRepertoire = await repertoire;
    await dataAccess.getOrAddMove(fromFen, move, toFen);
    return await dataAccess.getOrAddRepertoireMove(fromFen, move, currentRepertoire.id);
  }

  Future<List<MoveStat>> getMoveStats(String fen, bool myMove) async {
    var currentRepertoire = await repertoire;
    return await dataAccess.getMoveStats(fen, currentRepertoire.id, myMove);
  }

  Future<List<RepertoireMove>> getMoves(String fromFen) async {
    var currentRepertoire = await repertoire;
    return await dataAccess.getRepertoireMoves(fromFen, currentRepertoire.id);
  }

  Future<String> exportRepertoire(bool myMove) async {
    var currentRepertoire = await repertoire;
    return await dataAccess.exportRepertoire(currentRepertoire.id, myMove);
  }

  Future<void> importRepertoire(String pgn) async {
    var currentRepertoire = await repertoire;
    return await dataAccess.importRepertoire(currentRepertoire.id, pgn);
  }
}