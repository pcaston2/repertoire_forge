import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:dartchess/dartchess.dart';
import 'package:repertoire_forge/data_import.dart';
import 'package:repertoire_forge/database.dart' as db;
import 'package:repertoire_forge/repertoire_explorer.dart';
import 'package:repertoire_forge/chess_helper.dart';
import 'package:repertoire_forge/task.dart';
import 'package:repertoire_forge/task_banner.dart';
import 'data_access.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;

import 'engine.dart';
import 'game_explorer.dart';
import 'opening_trainer.dart';

late RepertoireExplorer explorer;
late DataAccess dataAccess;
late DataImport importer;

void main() async {
  var appDatabase = db.AppDatabase();
  dataAccess = DataAccess(appDatabase);
  var repertoirePage = const RepertoirePage();
  await repertoirePage.initAsync();
  runApp(repertoirePage);
}

class RepertoirePage extends StatelessWidget {
  Future<void> initAsync() async {
    await dataAccess.setUser("pcaston2");
  }

  const RepertoirePage({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Repertoire Forge',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blueGrey,
      ),
      home: const HomePage(title: 'Repertoire Forge'),
    );
  }
}

String pieceShiftMethodLabel(PieceShiftMethod method) {
  switch (method) {
    case PieceShiftMethod.drag:
      return 'Drag';
    case PieceShiftMethod.tapTwoSquares:
      return 'Tap two squares';
    case PieceShiftMethod.either:
      return 'Either';
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  Side orientation = Side.white;
  String fen = kInitialBoardFEN;
  NormalMove? lastMove;
  NormalMove? promotionMove;
  ValidMoves validMoves = IMap(const {});
  Side sideToMove = Side.white;
  bool get isWhite => orientation == Side.white;
  PieceSet pieceSet = PieceSet.gioco;
  PieceShiftMethod pieceShiftMethod = PieceShiftMethod.either;
  DragTargetKind dragTargetKind = DragTargetKind.circle;
  bool drawMode = true;
  bool pieceAnimation = true;
  bool dragMagnify = true;
  GameExplorer gameExplorer = GameExplorer();
  ISet<Shape> shapes = ISet();
  Arrow? engineMove;
  bool showBorder = false;
  bool addToRepertoire = false;
  List<db.RepertoireMove> repertoireMoves = [];
  late AnimationController controller;
  bool startup = true;
  int? gamesToImport;
  int? gamesToCompare;
  int? gamesToReview;
  Task? importArchivesTask;
  Task? importArchiveGamesTask;
  Task? parseGamesTask;
  Task? compareGamesTask;
  late Engine engine;

  Future<void> addUserDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Chess.com Account'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                const Text('Please enter your Chess.com account.'),
                TextField(
                    onSubmitted: (userName) async => {
                          await dataAccess.setUser(userName),
                          Navigator.of(context).pop(),
                          setState(() {})
                        }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            )
          ],
        );
      },
    );
  }

  Future<void> updateCounts() async {
    if (dataAccess.hasValidUser) {
      var importer = await DataImport.create(dataAccess);
      gamesToImport = await importer.getPendingImportGameCount();
      gamesToCompare = await dataAccess.getUncomparedGamesCount();
      gamesToReview = await dataAccess.getUnreviewedGamesCount();
    } else {
      gamesToImport = 0;
      gamesToCompare = 0;
      gamesToReview = 0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    Future.delayed(
        Duration.zero,
        () async => {
              if (startup)
                {
                  startup = false,
                  if (!(await dataAccess.hasUserProfile))
                    {
                      if (await showDialog<void>(
                        context: context,
                        barrierDismissible: false, // user must tap button!
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Add Chess.com Account'),
                            content: const SingleChildScrollView(
                              child: ListBody(
                                children: <Widget>[
                                  Text(
                                      'To get the most out of the this application, we suggest adding a Chess.com account.'),
                                  Text('Would you like to add one now?'),
                                ],
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text("I'll add it manually later"),
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                              ),
                              TextButton(
                                child: const Text('Yes Please!'),
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      ) as bool)
                        {await addUserDialog()}
                    },
                  await updateCounts(),
                },
            });

    final settingsWidgets = [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          IconButton(
            icon: const Icon(Icons.swap_vert_sharp),
            onPressed: () async {
              orientation = orientation.opposite;
              var moveStats = await explorer.getMoveStats(
                  gameExplorer.fen, orientation == gameExplorer.position.turn,
                  isWhite: isWhite);
              var newShapes = makeMoveArrows(moveStats);
              setState(() {
                shapes = newShapes;
              });
            },
            tooltip: "Rotate board",
          ),
          const Spacer(),
          IconButton(
            onPressed: () async {
              gameExplorer = GameExplorer();
              lastMove = null;
              await refresh();
            },
            icon: const Icon(Icons.restart_alt_sharp),
            tooltip: "Go to initial position",
          ),
          IconButton(
            onPressed: !gameExplorer.isAtInitial
                ? () async {
                    gameExplorer.reset();
                    lastMove = null;
                    await refresh();
                  }
                : null,
            icon: const Icon(Icons.first_page_sharp),
            tooltip: "Go to first move",
          ),
          IconButton(
            onPressed: !gameExplorer.isAtInitial
                ? () async {
                    gameExplorer.back();
                    lastMove = null;
                    await refresh();
                  }
                : null,
            icon: const Icon(Icons.chevron_left_sharp),
            tooltip: "Go to previous move",
          ),
          IconButton(
            onPressed: gameExplorer.hasAMove
                ? () async {
                    gameExplorer.forward();
                    lastMove = null;
                    await refresh();
                  }
                : null,
            icon: const Icon(Icons.chevron_right_sharp),
            tooltip: "Go to next move",
          ),
          IconButton(
            onPressed: gameExplorer.hasAMove
                ? () async {
                    gameExplorer.end();
                    lastMove = null;
                    await refresh();
                  }
                : null,
            icon: const Icon(Icons.last_page_sharp),
            tooltip: "Go to last move",
          ),
          const Spacer(),
        ],
      ),
      const Divider(),
      const Text("Repertoire"),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              icon: (gamesToImport == null
                  ? const Badge(
                      label: Text("?"), child: Icon(Icons.cloud_download_sharp))
                  : (gamesToImport! > 0
                      ? Badge.count(
                          count: gamesToImport!,
                          child: const Icon(Icons.cloud_download_sharp))
                      : const Icon(Icons.cloud_download_sharp))),
              onPressed: (dataAccess.hasValidUser
                  ? () async {
                      //showSnackbar(Icons.download, "Downloading from Chess.com");
                      var importer = await DataImport.create(dataAccess);
                      importArchivesTask = Task(importer.importArchives(),
                          name: "Importing archive list from Chess.com",
                          callback: (a) {
                        setState(() {});
                        //showSnackbar(Icons.add, "Added archive ${a.name}");
                      });
                      await importArchivesTask!.start();
                      if (importArchivesTask!.success) {
                        importArchivesTask = null;
                        importArchiveGamesTask = Task(
                            importer.importGamesInAllArchives(),
                            name: "Importing archives from Chess.com",
                            callback: (a) {
                          setState(() {});
                          //showSnackbar(Icons.download_done,
                          //"Imported all games in archive ${a.name}");
                        });
                        await importArchiveGamesTask!.start();
                        if (importArchiveGamesTask!.success) {
                          importArchiveGamesTask = null;
                          var count = await dataAccess.getUnimportedGameCount();
                          parseGamesTask = Task(importer.parseAllGames(),
                              name: "Parsing games",
                              totalItems: count, callback: (g) {
                            setState(() {});
                            //showSnackbar(Icons.data_array, "Parsed game ${g.uuid}");
                          });
                          await parseGamesTask!.start();
                          if (parseGamesTask!.success) {
                            setState(() {});
                            //showSnackbar(
                            //    Icons.check_circle, "Done importing games!");
                          }
                        }
                      }
                      await updateCounts();
                      setState(() {});
                    }
                  : null),
              tooltip: "Download from Chess.com",
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.file_download_sharp),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                    allowMultiple: true,
                    type: FileType.custom,
                    allowedExtensions: ['pgn']);
                if (result != null) {
                  List<io.File> files =
                      result.paths.map((p) => io.File(p!)).toList();
                  try {
                    for (var file in files) {
                      var pgn = await file.readAsString();
                      await explorer.importRepertoire(pgn, isWhite: isWhite);
                      showSnackbar(Icons.download_done,
                          "Import from ${path.basename(file.path)} done");
                    }
                    showSnackbar(
                        Icons.check_circle, "Done importing repertoire");
                  } catch (e) {
                    showSnackbar(Icons.close, e.toString());
                  }
                }
              },
              tooltip:
                  "Import ${(isWhite ? "White" : "Black")} Repertoire from PGN",
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_sharp),
              onPressed: () async {
                String? path = await FilePicker.platform.saveFile(
                    type: FileType.custom, allowedExtensions: ['pgn']);
                try {
                  if (path != null) {
                    var filePath = io.File(path);
                    var repertoire = await explorer.exportRepertoire(
                        orientation == gameExplorer.position.turn,
                        isWhite: isWhite);
                    await filePath.writeAsString(repertoire);
                    showSnackbar(
                        Icons.check_circle, "Export to ${filePath.path} done");
                  }
                } catch (e) {
                  showSnackbar(Icons.close, e.toString());
                }
              },
              tooltip:
                  "Export ${(isWhite ? "White" : "Black")} Repertoire to PGN file",
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.playlist_add_check_sharp),
              onPressed: () async {
                var paths = await explorer.getReviewPaths(isWhite: isWhite);
                Random r = Random();
                paths.forEach((p) => p.score *= r.nextDouble());
                paths.sort((a, b) => a.score.compareTo(b.score));
                for (var p in paths) {
                  bool cont = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OpeningTrainer(
                              title: 'Training',
                              pgn: p.path,
                              isWhite: isWhite))) as bool;
                  if (!cont) {
                    break;
                  }
                }
              },
              tooltip: "Training",
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_sharp),
              onPressed: () async {
                if (!gameExplorer.isAtInitial) {
                  var lastMove = gameExplorer.lastMove;
                  await refresh();
                  await explorer.removeMove(gameExplorer.fen, lastMove,
                      isWhite: isWhite);
                }
              },
              tooltip: "Remove from Repertoire",
            ),
            IconButton(
              icon: Icon((addToRepertoire ? Icons.edit : Icons.edit_off_sharp)),
              onPressed: () async {
                setState(() {
                  addToRepertoire = !addToRepertoire;
                });
              },
              tooltip: "Track Repertoire",
            ),
          ]),
      const Divider(),
      const Text("Comparison"),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              icon: (gamesToCompare == null
                  ? const Badge(
                      label: Text("?"), child: Icon(Icons.compare_arrows_sharp))
                  : (gamesToCompare! > 0
                      ? Badge.count(
                          count: gamesToCompare!,
                          child: const Icon(Icons.compare_arrows_sharp))
                      : const Icon(Icons.compare_arrows_sharp))),
              onPressed: () async {
                var count = await dataAccess.getUncomparedGamesCount();
                compareGamesTask = Task(explorer.compareAllGames(),
                    name: "Comparing games", totalItems: count, callback: (g) {
                  setState(() {});
                });
                await compareGamesTask!.start();
                if (compareGamesTask!.success) {
                  await updateCounts();
                }
                setState(() {});
              },
              tooltip: "Compare all games",
            ),
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: () async {
                await explorer.markAllGamesCompared();
                setState(() {});
              },
              tooltip: "Mark all games as compared",
            ),
            const Spacer(),
            IconButton(
              icon: (gamesToReview == null
                  ? const Badge(
                      label: Text("?"), child: Icon(Icons.rate_review_sharp))
                  : (gamesToReview! > 0
                      ? Badge.count(
                          count: gamesToReview!,
                          child: const Icon(Icons.rate_review_sharp))
                      : const Icon(Icons.rate_review_sharp))),
              onPressed: () async {
                var comparisons = await explorer.getUnreviewedComparisons();
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        content: Container(
                          width: double.maxFinite,
                          child: ListView.separated(
                            itemCount: comparisons.length,
                            itemBuilder: (BuildContext context, int index) {
                              return Card(
                                  color: (comparisons[index].comparison.deviated
                                          ? (comparisons[index]
                                                  .comparison
                                                  .myMove
                                              ? Colors.redAccent
                                              : Colors.yellowAccent)
                                          : Colors.lightGreenAccent)
                                      .shade100
                                      .withAlpha(150),
                                  child: Container(
                                      padding: EdgeInsets.all(5),
                                      child: Column(children: [
                                        Row(children: [
                                          Chessboard.fixed(
                                            size: 120,
                                            orientation: (comparisons[index]
                                                    .game
                                                    .isWhite!
                                                ? Side.white
                                                : Side.black),
                                            settings: const ChessboardSettings(
                                              pieceAssets:
                                                  PieceSet.mpchessAssets,
                                              enableCoordinates: false,
                                            ),
                                            fen: comparisons[index]
                                                .comparison
                                                .fromFen,
                                          ),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Row(children: [
                                                  Icon(Icons.flag_circle,
                                                      color: (comparisons[index]
                                                                  .game
                                                                  .score ==
                                                              1
                                                          ? Colors.green
                                                          : (comparisons[index]
                                                                      .game
                                                                      .score ==
                                                                  0
                                                              ? Colors.red
                                                              : Colors.white))),
                                                  Text(
                                                      "${comparisons[index].game.opponentUser!} (${comparisons[index].game.opponentRating!})")
                                                ]),
                                                Text(DataImport.prettyDate(
                                                    comparisons[index]
                                                        .game
                                                        .startDate!)),
                                                TextButton(
                                                  onPressed: () async {
                                                    var game = await dataAccess
                                                        .getGame(
                                                            comparisons[index]
                                                                .game
                                                                .uuid);
                                                    gameExplorer =
                                                        GameExplorer.fromPgn(
                                                            game.pgn);
                                                    for (int i = 1;
                                                        i <
                                                            comparisons[index]
                                                                .comparison
                                                                .moveNumber;
                                                        i++) {
                                                      gameExplorer.forward();
                                                    }
                                                    orientation =
                                                        (comparisons[index]
                                                                .game
                                                                .isWhite!
                                                            ? Side.white
                                                            : Side.black);
                                                    await refresh();
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text("Review"),
                                                )
                                              ])),
                                        ]),
                                        Row(children: [
                                          Text(comparisons[index]
                                              .game
                                              .openingName!),
                                        ])
                                      ])));
                            },
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const SizedBox(height: 5),
                          ),
                        ),
                      );
                    });
                setState(() {});
              },
              tooltip: "Review game comparisons",
            ),
            IconButton(
              icon: const Icon(Icons.check_box_outlined),
              onPressed: () async {
                await explorer.markAllComparisonsReviewed();
                await updateCounts();
                setState(() {});
              },
              tooltip: "Mark all comparisons reviewed",
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.thumb_up_sharp),
              onPressed: () async {
                var recommendations = await explorer.getRecommendedReviews();
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView.separated(
                            itemCount: recommendations.length,
                            itemBuilder: (BuildContext context, int index) {
                              return ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 120,
                                    color: (recommendations[index].score > 10
                                            ? Colors.redAccent
                                            : (recommendations[index].score > 5
                                                ? Colors.orangeAccent
                                                : (recommendations[index]
                                                            .score >
                                                        1
                                                    ? Colors.yellowAccent
                                                    : Colors.greenAccent)))
                                        .shade100,
                                    child: Row(children: [
                                      Chessboard.fixed(
                                        size: 120,
                                        orientation: Setup.parseFen(
                                                recommendations[index].fen)
                                            .turn,
                                        settings: ChessboardSettings(
                                          pieceAssets: PieceSet.mpchessAssets,
                                          enableCoordinates: false,
                                        ),
                                        fen: recommendations[index].fen,
                                      ),
                                      const Spacer(),
                                      Column(children: [
                                        const Spacer(),
                                        Text(
                                            "Score: ${recommendations[index].score.round()}"),
                                        const Spacer(),
                                        Text(
                                            "Age: ${recommendations[index].age}"),
                                        const Spacer(),
                                        Text(
                                            "Occurrence: ${recommendations[index].occurrences}"),
                                        const Spacer(),
                                      ]),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () async {
                                          gameExplorer = GameExplorer.fromFen(
                                              recommendations[index].fen);
                                          orientation =
                                              gameExplorer.position.turn;
                                          await refresh();
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Review"),
                                      )
                                    ]),
                                  ));
                            },
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const SizedBox(height: 5),
                          ),
                        ),
                      );
                    });
                setState(() {});
              },
              tooltip: "Review recommendations",
            ),
          ]),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Repertoire Forge')),
      drawer: Drawer(
          child: ListView(
        children: [
          ExpansionTile(title: const Text("Settings"), children: [
            ElevatedButton(
              child: Text('Drag target: ${dragTargetKind.name}'),
              onPressed: () => _showChoicesPicker<DragTargetKind>(
                context,
                choices: DragTargetKind.values,
                selectedItem: dragTargetKind,
                labelBuilder: (t) => Text(t.name),
                onSelectedItemChanged: (DragTargetKind value) {
                  setState(() {
                    dragTargetKind = value;
                  });
                },
              ),
            ),
            ElevatedButton(
              child: Text("Magnify drag: ${dragMagnify ? 'ON' : 'OFF'}"),
              onPressed: () {
                setState(() {
                  dragMagnify = !dragMagnify;
                });
              },
            ),
            ElevatedButton(
              child: Text(
                  'Piece Shift: ${pieceShiftMethodLabel(pieceShiftMethod)}'),
              onPressed: () => _showChoicesPicker<PieceShiftMethod>(
                context,
                choices: PieceShiftMethod.values,
                selectedItem: pieceShiftMethod,
                labelBuilder: (t) => Text(pieceShiftMethodLabel(t)),
                onSelectedItemChanged: (PieceShiftMethod? value) {
                  setState(() {
                    if (value != null) {
                      pieceShiftMethod = value;
                    }
                  });
                },
              ),
            ),
            ElevatedButton(
              child: Text("Show border: ${showBorder ? 'ON' : 'OFF'}"),
              onPressed: () {
                setState(() {
                  showBorder = !showBorder;
                });
              },
            ),
            ElevatedButton(
              child: Text('Piece set: ${pieceSet.label}'),
              onPressed: () => _showChoicesPicker<PieceSet>(
                context,
                choices: PieceSet.values,
                selectedItem: pieceSet,
                labelBuilder: (t) => Text(t.label),
                onSelectedItemChanged: (PieceSet? value) {
                  setState(() {
                    if (value != null) {
                      pieceSet = value;
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              child: Text("Piece animation: ${pieceAnimation ? 'ON' : 'OFF'}"),
              onPressed: () {
                setState(() {
                  pieceAnimation = !pieceAnimation;
                });
              },
            ),
          ]),
        ],
      )),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          (importArchivesTask == null
              ? const SizedBox.shrink()
              : TaskBanner(importArchivesTask!, callback: () {
                  parseGamesTask = null;
                  setState(() {});
                })),
          (importArchiveGamesTask == null
              ? const SizedBox.shrink()
              : TaskBanner(importArchiveGamesTask!, callback: () {
                  parseGamesTask = null;
                  setState(() {});
                })),
          (parseGamesTask == null
              ? const SizedBox.shrink()
              : TaskBanner(parseGamesTask!, callback: () {
                  parseGamesTask = null;
                  setState(() {});
                })),
          (compareGamesTask == null
              ? const SizedBox.shrink()
              : TaskBanner(compareGamesTask!, callback: () {
                  compareGamesTask = null;
                  setState(() {});
                })),
          Chessboard(
            size: screenWidth,

            settings: ChessboardSettings(
              pieceAssets: pieceSet.assets,
              border: (addToRepertoire
                  ? const BoardBorder(color: Colors.redAccent, width: 20)
                  : (showBorder
                      ? const BoardBorder(color: Colors.black, width: 15)
                      : null)),
              enableCoordinates: true,
              animationDuration: pieceAnimation
                  ? const Duration(milliseconds: 200)
                  : Duration.zero,
              dragFeedbackScale: dragMagnify ? 2.0 : 1.0,
              dragTargetKind: dragTargetKind,
              drawShape: DrawShapeOptions(
                enable: drawMode,
                onCompleteShape: _onCompleteShape,
                onClearShapes: () {
                  setState(() {});
                },
              ),
              pieceShiftMethod: pieceShiftMethod,
              autoQueenPromotionOnPremove: false,
              pieceOrientationBehavior: PieceOrientationBehavior.facingUser,
            ),
            orientation: orientation,
            fen: fen,
            lastMove: lastMove,
            game: GameData(
              playerSide: (gameExplorer.position.turn == Side.white
                  ? PlayerSide.white
                  : PlayerSide.black),
              validMoves: validMoves,
              sideToMove: gameExplorer.position.turn == Side.white
                  ? Side.white
                  : Side.black,
              isCheck: gameExplorer.position.isCheck,
              promotionMove: promotionMove,
              onMove: _playMove,
              onPromotionSelection: _onPromotionSelection,
            ),
            shapes: shapes.isNotEmpty ? (engineMove != null ? shapes.add(engineMove!) : shapes) : (engineMove == null ? null : ISet<Shape>().add(engineMove!)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: settingsWidgets,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Future<void> refresh() async {
    var moveStats = await explorer.getMoveStats(
        gameExplorer.fen, orientation == gameExplorer.position.turn,
        isWhite: isWhite);
    var initShapes = makeMoveArrows(moveStats);
    setState(() {
      fen = gameExplorer.fen;
      validMoves = makeLegalMoves(gameExplorer.position);
      shapes = initShapes;
    });
  }

  void _onCompleteShape(Shape shape) {
    if (shapes.any((element) => element == shape)) {
      setState(() {
        shapes = shapes.remove(shape);
      });
      return;
    } else {
      setState(() {
        shapes = shapes.add(shape);
      });
    }
  }

  void _showChoicesPicker<T extends Enum>(
    BuildContext context, {
    required List<T> choices,
    required T selectedItem,
    required Widget Function(T choice) labelBuilder,
    required void Function(T choice) onSelectedItemChanged,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(top: 12),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((value) {
              return RadioListTile<T>(
                title: labelBuilder(value),
                value: value,
                groupValue: selectedItem,
                onChanged: (value) {
                  if (value != null) onSelectedItemChanged(value);
                  Navigator.of(context).pop();
                },
              );
            }).toList(growable: false),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    engine = Engine.create((engineInfo) {
      var move = Move.parse(engineInfo.principalVariation.first);
      if (move != null) {
        engineMove = Arrow(
            color: Colors.lightGreenAccent.withAlpha(150),
            orig: move.squares.first,
            dest: move.squares.last,
            scale: 0.3);
        setState(() {

        });
      }
    });

    var appDatabase = db.AppDatabase();
    dataAccess = DataAccess(appDatabase);
    explorer = RepertoireExplorer(dataAccess: dataAccess);

    controller = AnimationController(
      duration: const Duration(seconds: 0),
      value: 1,
      vsync: this,
    );

    validMoves = makeLegalMoves(gameExplorer.position);
    explorer
        .getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(gameExplorer.fen),
            orientation == gameExplorer.position.turn,
            isWhite: isWhite)
        .then((List<MoveStat> moveStats) {
      var initShapes = makeMoveArrows(moveStats);
      setState(() {
        shapes = initShapes;
      });
    });
  }

  void _onPromotionSelection(Role? role) {
    if (role == null) {
      _onPromotionCancel();
    } else if (promotionMove != null) {
      _playMove(promotionMove!.withPromotion(role));
    }
  }

  void _onPromotionCancel() {
    setState(() {
      promotionMove = null;
    });
  }

  ISet<Shape> makeMoveArrows(List<MoveStat> moveStats) {
    var position = gameExplorer.position;
    var newShapes = ISet<Shape>();
    var threshold = 0.05;
    bool main = true;
    engine.setPosition(ChessHelper.addFakeMoveClockInfoToFen(position.fen));
    for (var m in gameExplorer.getMoves()) {
      var move = position.parseSan(m);
      var squares = move!.squares.toList();
      newShapes = newShapes.add(Arrow(
        color: (Colors.black54),
        orig: squares.first,
        dest: squares.last,
        scale: (main ? 0.5 : 0.2),
      ));
      main = false;
    }
    if (moveStats.isEmpty) {
      return newShapes;
    }
    var max = moveStats
        .reduce((curr, next) => curr.count > next.count ? curr : next)
        .count;
    for (var m in moveStats) {
      if (m.count / max < threshold && !m.repo) {
        continue;
      }
      var move = position.parseSan(m.move);
      var squares = move!.squares.toList();
      double scoreOpacity(double score) {
        if (score > 0.6) {
          return 0.8;
        } else if (score > 0.55) {
          return 0.7;
        } else if (score > 0.45) {
          return 0.5;
        } else if (score > 0.4) {
          return 0.3;
        } else {
          return 0.2;
        }
      }

      newShapes = newShapes.add(Arrow(
        color: (m.repo ? Colors.lightBlueAccent : Colors.orangeAccent)
            .withAlpha((orientation == gameExplorer.position.turn
                    ? (256 * scoreOpacity(m.score))
                    : 1 - (256 * scoreOpacity(m.score)))
                .round()),
        orig: squares.first,
        dest: squares.last,
        scale: 0.2 + 0.8 * (max == 0 ? 0 : (m.count / max)),
      ));
    }
    return newShapes;
  }

  Future<void> _playMove(NormalMove move,
      {bool? isDrop, bool? isPremove}) async {
    var currentFen = gameExplorer.fen;
    var sanMove = gameExplorer.position.makeSan(move).$2;
    if (isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else if (gameExplorer.position.isLegal(move)) {
      if (addToRepertoire) {
        await explorer.addMove(currentFen, sanMove, gameExplorer.fen,
            isWhite: isWhite);
      }
      gameExplorer.move(sanMove);
      var moveStats = await explorer.getMoveStats(
          gameExplorer.fen, orientation == gameExplorer.position.turn,
          isWhite: isWhite);
      var newShapes = makeMoveArrows(moveStats);
      setState(() {
        shapes = newShapes;
        lastMove = move;
        fen = gameExplorer.fen;
        validMoves = makeLegalMoves(gameExplorer.position);
        promotionMove = null;
      });
    }
  }

  bool isPromotionPawnMove(NormalMove move) {
    return move.promotion == null &&
        gameExplorer.position.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first &&
                gameExplorer.position.turn == Side.black) ||
            (move.to.rank == Rank.eighth &&
                gameExplorer.position.turn == Side.white));
  }

  showSnackbar(IconData icon, String message) {
    Color background = Colors.black;
    switch (icon) {
      case Icons.check_circle:
        background = Colors.green;
      case Icons.close:
        background = Colors.red;
    }
    var snackbar = SnackBar(
        content: Row(
            children: [Icon(icon, color: Colors.blueAccent), Text(message)]),
        animation: controller,
        behavior: SnackBarBehavior.floating,
        backgroundColor: background);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }
}
