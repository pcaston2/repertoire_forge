import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

class _HomePageState extends State<HomePage> {
  Position<Chess> position = Chess.initial;
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
  List<ChessMoveHistoryEntry> history = [];
  ISet<Shape> shapes = ISet();
  bool showBorder = false;
  bool addToRepertoire = false;
  List<db.RepertoireMove> repertoireMoves = [];
  FToast fToast = FToast();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    final settingsWidgets = [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          IconButton(
            icon: Icon(Icons.swap_vert_sharp),
            onPressed: () async {
              orientation = orientation.opposite;
              var moveStats = await explorer.getMoveStats(
                  ChessHelper.stripMoveClockInfoFromFEN(position.fen),
                  orientation == position.turn,
                  isWhite: isWhite);
              var newShapes = makeMoveArrows(moveStats, position);
              setState(() {
                shapes = newShapes;
              });
            },
            tooltip: "Rotate board",
          ),
          Spacer(),
          IconButton(
              onPressed: history.isNotEmpty ? () async {
                position = Chess.initial;
                var moveStats = await explorer.getMoveStats(
                    ChessHelper.stripMoveClockInfoFromFEN(position.fen),
                    orientation == position.turn, isWhite: isWhite);
                var initShapes = makeMoveArrows(moveStats, position);
                setState(() {
                  lastMove = null;
                  fen = position.fen;
                  history = [];
                  sideToMove = Side.white;
                  validMoves = makeLegalMoves(position);
                  promotionMove = null;
                  shapes = initShapes;
                });
              } : null,
              icon: const Icon(Icons.first_page_sharp),
              tooltip: "Go to initial position",
          ),
          IconButton(
              onPressed: history.isNotEmpty
                  ? ()  async {
                await undo();
              }
                  : null,
              icon: const Icon(Icons.chevron_left_sharp),
              tooltip: "Go to previous move",
          ),
          IconButton(
              onPressed: null,
              icon: const Icon(Icons.chevron_right_sharp),
              tooltip: "Go to next move",
          ),
          IconButton(
              onPressed: null,
              icon: const Icon(Icons.last_page_sharp),
              tooltip: "Go to last move",
          ),
        ],
      ),
      Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              icon: const Icon(Icons.file_download_sharp),
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['pgn']);
                if (result != null) {
                  List<io.File> files = result.paths.map((p) => io.File(p!)).toList();
                  for (var file in files) {
                    _showToast("Importing from ${path.basename(file.path)}...", icon: Icons.hourglass_bottom, color: Colors.blueAccent);
                    var pgn = await file.readAsString();
                    await explorer.importRepertoire(pgn, isWhite: isWhite);
                    _showToast("Import from ${path.basename(file.path)} successful!", icon: Icons.check);
                  }
                }
              },
              tooltip: "Import PGN",
            ),
            IconButton(
              icon: const Icon(Icons.file_upload_sharp),
              onPressed: () async {
                String? path = await FilePicker.platform.saveFile(type: FileType.custom, allowedExtensions: ['pgn']);
                if (path != null) {
                  var filePath = io.File(path);
                  var repertoire = await explorer.exportRepertoire(orientation == position.turn, isWhite: isWhite);
                  _showToast("Exporting to ${filePath.path}...", icon: Icons.hourglass_bottom, color: Colors.blueAccent);
                  await filePath.writeAsString(repertoire);
                  _showToast("Export to ${filePath.path} successful!", icon: Icons.check);
                }
              },
              tooltip: "Export PGN",
            ),
            Spacer(),
            IconButton(
              icon: const Icon(Icons.cloud_download_sharp),
              onPressed: () async {
                _showToast("Downloading from Chess.com...", icon: Icons.hourglass_full, color: Colors.blueAccent);
                var importer = await DataImport.create(dataAccess);
                await importer.importArchives();
                await importer.importAllGames();
                await importer.parseAllGames();
                _showToast("Download from Chess.com successful!", icon: Icons.check);
              },
              tooltip: "Download from Chess.com",
            ),
            Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_sharp),
              onPressed: () async {
                if (history.isNotEmpty) {
                  var last = history.last;
                  var lastPosition = last.position;
                  var move = lastPosition.makeSan(last.move);
                  await explorer.removeMove(ChessHelper.stripMoveClockInfoFromFEN(lastPosition.fen), move.$2, isWhite: isWhite);
                  await undo();
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
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          IconButton(
            icon: Icon(Icons.check_circle),
            onPressed: () async {
              await explorer.markAllGamesCompared();
              setState(() {
              });
            },
            tooltip: "Mark all games as compared",
          ),

          IconButton(
            icon: Icon(Icons.rate_review_sharp),
            onPressed: () async {
              setState(() {
              });
            },
            tooltip: "Review Game Comparisons",
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.compare_arrows_sharp),
            onPressed: () async {
              await explorer.compareAllGames();
              setState(() {
              });
            },
            tooltip: "Compare all games",
          ),
        ]),
    ];

    return Scaffold(
      appBar: AppBar(
          title: const Text('Free Play')
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
              playerSide: (position.turn == Side.white
                  ? PlayerSide.white
                  : PlayerSide.black),
              validMoves: validMoves,
              sideToMove: position.turn == Side.white ? Side.white : Side.black,
              isCheck: position.isCheck,
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

  Future<void> undo() async {
    if (history.isNotEmpty) {
      position = history.last.position;
    } else {
      position = Chess.initial;
    }
    var moveStats = await explorer.getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(position.fen), orientation == position.turn, isWhite: isWhite);
    var initShapes = makeMoveArrows(moveStats, position);
    setState(() {
            fen = position.fen;
            validMoves = makeLegalMoves(position);
            history.removeLast();
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

    validMoves = makeLegalMoves(position);
    explorer.getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(position.fen), orientation == position.turn, isWhite: isWhite).
    then((List<MoveStat> moveStats) {
      var initShapes = makeMoveArrows(moveStats, position);
        setState(() {
          shapes = initShapes;
        });
      });
    fToast.init(context);
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
    if (moveStats.isEmpty) {
      return ISet<Shape>();
    }
    var max = moveStats.reduce((curr, next) => curr.count > next.count ? curr : next).count;

    var newShapes = ISet<Shape>();
    var threshold = 0.05;
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
    var sanMove = position.makeSan(move).$2;
    history.add(ChessMoveHistoryEntry(position, move));
    if (isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else if (position.isLegal(move)) {
      if (addToRepertoire) {
        await explorer.addMove(
            ChessHelper.stripMoveClockInfoFromFEN(history.last.position.fen), sanMove,
            ChessHelper.stripMoveClockInfoFromFEN(position.fen), isWhite: isWhite);
      }
      var newPosition = position.playUnchecked(move);
      var moveStats = await explorer.getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(newPosition.fen),orientation == newPosition.turn, isWhite: isWhite);
      var newShapes = makeMoveArrows(moveStats, newPosition);
      setState(() {
        shapes = newShapes;
        position = newPosition;
        lastMove = move;
        fen = position.fen;
        validMoves = makeLegalMoves(position);
        promotionMove = null;
      });
    }
  }

  bool isPromotionPawnMove(NormalMove move) {
    return move.promotion == null &&
        position.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && position.turn == Side.black) ||
            (move.to.rank == Rank.eighth && position.turn == Side.white));
  }


  _showToast(String message, {IconData icon = Icons.info, Color color = Colors.greenAccent}) {
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: color,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(
            width: 12.0,
          ),
          Text(message),
        ],
      ),
    );


    fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 2),
    );
  }

}

class ChessMoveHistoryEntry {
  late Position<Chess> position;
  late NormalMove move;

  ChessMoveHistoryEntry(this.position, this.move);
}