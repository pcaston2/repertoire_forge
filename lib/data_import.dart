import 'package:repertoire_forge/database.dart';

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

  importGames() async {
    var archives = await dataAccess.archives;
    for (var a in archives) {
      await importGamesInArchive(a.name);
    }
  }
}