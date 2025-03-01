import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:dartchess/dartchess.dart';
import 'package:repertoire_forge/data_import.dart';
import 'package:repertoire_forge/database.dart' as db;
import 'package:repertoire_forge/repertoire_explorer.dart';
import 'package:repertoire_forge/chess_helper.dart';
import 'data_access.dart';
import 'dart:io' as io;
import 'package:path/path.dart' as path;

import 'game_explorer.dart';


late RepertoireExplorer explorer;
late DataAccess dataAccess;
late DataImport importer;

void main() async {
  var appDatabase = db.AppDatabase();
  dataAccess = DataAccess(appDatabase);
  await dataAccess.setUser("pcaston2");
  explorer = await RepertoireExplorer.create(dataAccess);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin  {
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
  bool showBorder = false;
  bool addToRepertoire = false;
  List<db.RepertoireMove> repertoireMoves = [];
  late AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

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
                  gameExplorer.fen,
                  orientation == gameExplorer.position.turn,
                  isWhite: isWhite);
              var newShapes = makeMoveArrows(moveStats, gameExplorer.position);
              setState(() {
                shapes = newShapes;
              });
            },
            tooltip: "Rotate board",
          ),
          const Spacer(),
          IconButton(
              onPressed: !gameExplorer.isAtInitial ? () async {
                gameExplorer.reset();
                var moveStats = await explorer.getMoveStats(
                    gameExplorer.fen,
                    orientation == gameExplorer.position.turn, isWhite: isWhite);
                var initShapes = makeMoveArrows(moveStats, gameExplorer.position);
                setState(() {
                  lastMove = null;
                  fen = gameExplorer.fen;
                  sideToMove = Side.white;
                  validMoves = makeLegalMoves(gameExplorer.position);
                  promotionMove = null;
                  shapes = initShapes;
                });
              } : null,
              icon: const Icon(Icons.first_page_sharp),
              tooltip: "Go to initial position",
          ),
          IconButton(
              onPressed: !gameExplorer.isAtInitial
                  ? ()  async {
                gameExplorer.back();
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
                await refresh();
              }
              : null,
              icon: const Icon(Icons.last_page_sharp),
              tooltip: "Go to last move",
          ),
          Spacer(),
        ],
      ),
      Divider(),
      Text("Repertoire"),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              icon: const Icon(Icons.cloud_download_sharp),
              onPressed: () async {
                try {
                  showSnackbar(Icons.download, "Downloading from Chess.com");
                  var importer = await DataImport.create(dataAccess);
                  await for (var a in importer.importArchives()) {
                    showSnackbar(Icons.add, "Added archive ${a.name}");
                  }
                  await for (var a in importer.importGamesInAllArchives()) {
                    showSnackbar(Icons.download_done,
                        "Imported all games in archive ${a.name}");
                  }
                  await for (var g in importer.parseAllGames()) {
                    showSnackbar(Icons.data_array, "Parsed game ${g.uuid}");
                  }
                  showSnackbar(
                  Icons.check_circle, "Done downloading from Chess.com");
                }  catch (e) {
                  showSnackbar(Icons.close, e.toString());
                  rethrow;
                }
              },
              tooltip: "Download from Chess.com",
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.file_download_sharp),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['pgn']);
                if (result != null) {
                  List<io.File> files = result.paths.map((p) => io.File(p!)).toList();
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
                    showSnackbar(
                        Icons.close, e.toString()
                    );
                  }
                }
              },
              tooltip: "Import ${(isWhite ? "White" : "Black")} Repertoire from PGN",
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_sharp),
              onPressed: () async {
                String? path = await FilePicker.platform.saveFile(type: FileType.custom, allowedExtensions: ['pgn']);
                try {
                  if (path != null) {
                    var filePath = io.File(path);
                    var repertoire = await explorer.exportRepertoire(orientation == gameExplorer.position.turn, isWhite: isWhite);
                    await filePath.writeAsString(repertoire);
                    showSnackbar(Icons.check_circle, "Export to ${filePath.path} done");
                  }
                } catch (e) {
                  showSnackbar(Icons.close, e.toString());
                }
              },
              tooltip: "Export ${(isWhite ? "White" : "Black")} Repertoire to PGN file",
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_sharp),
              onPressed: () async {
                if (!gameExplorer.isAtInitial) {
                  var lastMove = gameExplorer.lastMove;
                  await refresh();
                  await explorer.removeMove(gameExplorer.fen, lastMove, isWhite: isWhite);
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
          ]
      ),
      Divider(),
      Text("Comparison"),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle),
            onPressed: () async {
              await explorer.markAllGamesCompared();
              setState(() {
              });
            },
            tooltip: "Mark all games as compared",
          ),

          IconButton(
            icon: const Icon(Icons.rate_review_sharp),
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
                            return Container(
                              height: 30,
                              color: (comparisons[index].comparison.deviated ? (comparisons[index].comparison.myMove ? Colors.redAccent : Colors.yellowAccent) : Colors.lightGreenAccent ).shade100,
                              child: Row(
                                children: [
                                  Icon(Icons.format_list_numbered),
                                  Text(comparisons[index].comparison.moveNumber.toString()),
                                  Icon(Icons.forward, color: (comparisons[index].game.isWhite! ? Colors.white : Colors.black)),
                                  Text(comparisons[index].comparison.move),
                                  Icon(Icons.flag, color: (comparisons[index].game.score == 1 ? Colors.green : comparisons[index].game.score == 0 ? Colors.red : Colors.white)),
                                  Text("${comparisons[index].game.opponentUser!} (${comparisons[index].game.oppenentRating!})"),
                                  Icon(Icons.watch_later),
                                  Text("${DataImport.prettyDate(comparisons[index].game.startDate!)}"),
                                  Spacer(),
                                  TextButton(
                                    onPressed: () async { 
                                      var game = await dataAccess.getGame(comparisons[index].comparison.game);
                                      orientation = (game.isWhite! ? Side.white : Side.black);
                                      gameExplorer = GameExplorer.fromPgn(game.pgn);
                                      for (int i = 0; i < comparisons[index].comparison.moveNumber; i++) {
                                        gameExplorer.forward();
                                      }
                                      await refresh();
                                      Navigator.pop(context);
                                    }, child: Text("Review"),
                                  )
                                ]
                              ),
                            );
                          }, separatorBuilder: (BuildContext context, int index) => const Spacer(),

                        ),
                      ),
                    );
                  }
              );
              setState(() {
              });
            },
            tooltip: "Review game comparisons",
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.compare_arrows_sharp),
            onPressed: () async {
              try {
                await explorer.compareAllGames();
                showSnackbar(Icons.check_circle, "Game comparisons done");
              } catch (e) {
                showSnackbar(Icons.close, e.toString());
              }
              setState(() {
              });
            },
            tooltip: "Compare all games",
          ),
        ]),
    ];

    return Scaffold(
      appBar: AppBar(
          title: const Text('Repertoire Forge')
      ),
      drawer: Drawer(
          child: ListView(
            children: [
              ExpansionTile(
                  title: const Text("Settings"),
                  children: [
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
                      child:
                      Text('Piece Shift: ${pieceShiftMethodLabel(pieceShiftMethod)}'),
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
                  ]
              ),

            ],
          )),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Chessboard(
            size: screenWidth,
            settings: ChessboardSettings(
              pieceAssets: pieceSet.assets,
              border: (showBorder ? const BoardBorder(color: Colors.black, width: 15) : null),
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
              sideToMove: gameExplorer.position.turn == Side.white ? Side.white : Side.black,
              isCheck: gameExplorer.position.isCheck,
              promotionMove: promotionMove,
              onMove: _playMove,
              onPromotionSelection: _onPromotionSelection,
            ),
            shapes: shapes.isNotEmpty ? shapes : null,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: settingsWidgets,
          ),
        ],
      ),
    );
  }

  Future<void> refresh() async {
    var moveStats = await explorer.getMoveStats(gameExplorer.fen, orientation == gameExplorer.position.turn, isWhite: isWhite);
    var initShapes = makeMoveArrows(moveStats, gameExplorer.position);
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


    controller = AnimationController(
      duration: const Duration(seconds: 0),
      value: 1,
      vsync: this,
    );

    validMoves = makeLegalMoves(gameExplorer.position);
    explorer.getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(gameExplorer.fen), orientation == gameExplorer.position.turn, isWhite: isWhite).
    then((List<MoveStat> moveStats) {
      var initShapes = makeMoveArrows(moveStats, gameExplorer.position);
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

  ISet<Shape> makeMoveArrows(List<MoveStat> moveStats, Position position) {

    var newShapes = ISet<Shape>();
    var threshold = 0.05;
    bool main = true;
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
    var max = moveStats.reduce((curr, next) => curr.count > next.count ? curr : next).count;
    for (var m in moveStats) {
      if (m.count / max < threshold && !m.repo) {
        continue;
      }
      var move = position.parseSan(m.move);
      var squares = move!.squares.toList();
      newShapes = newShapes.add(Arrow(
        color: (m.repo ? Colors.lightBlueAccent : Colors.orangeAccent).withAlpha(128+(64*m.score).round()),
        orig: squares.first,
        dest: squares.last,
        scale: 0.2 + 0.8 * (max == 0 ? 0 : (m.count / max)),
      ));
    }
    return newShapes;
  }

  Future<void> _playMove(NormalMove move, {bool? isDrop, bool? isPremove}) async {
    var currentFen = gameExplorer.fen;
    var sanMove = gameExplorer.position.makeSan(move).$2;
    if (isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else if (gameExplorer.position.isLegal(move)) {
      if (addToRepertoire) {
        await explorer.addMove(currentFen, sanMove, gameExplorer.fen, isWhite: isWhite);
      }
      gameExplorer.move(sanMove);
      var moveStats = await explorer.getMoveStats(gameExplorer.fen, orientation == gameExplorer.position.turn, isWhite: isWhite);
      var newShapes = makeMoveArrows(moveStats, gameExplorer.position);
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
        ((move.to.rank == Rank.first && gameExplorer.position.turn == Side.black) ||
            (move.to.rank == Rank.eighth && gameExplorer.position.turn == Side.white));
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
        children: [
        Icon(icon, color: Colors.blueAccent),
        Text(message)
        ]),
        animation: controller,
        behavior: SnackBarBehavior.floating,
        backgroundColor: background);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackbar);
  }


}