import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chessground/chessground.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:dartchess/dartchess.dart';
import 'package:repertoire_forge/data_import.dart';
import 'package:repertoire_forge/database.dart' as db;
import 'package:repertoire_forge/repertoire_explorer.dart';
import 'package:repertoire_forge/chess_helper.dart';
import 'data_access.dart';

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
      title: 'Chessground Demo',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.blueGrey,
      ),
      home: const HomePage(title: 'Chessground Demo'),
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
  NormalMove? premove;
  ValidMoves validMoves = IMap(const {});
  Side sideToMove = Side.white;
  PieceSet pieceSet = PieceSet.gioco;
  PieceShiftMethod pieceShiftMethod = PieceShiftMethod.either;
  DragTargetKind dragTargetKind = DragTargetKind.circle;
  bool drawMode = true;
  bool pieceAnimation = true;
  bool dragMagnify = true;
  Position<Chess>? lastPos;
  ISet<Shape> shapes = ISet();
  bool showBorder = false;
  bool addToRepertoire = false;
  List<db.RepertoireMove> repertoireMoves = [];

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    final settingsWidgets = [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          ElevatedButton(
            child: const Text("remove"),
            onPressed: () async {
              print("remove");
            },
          ),
          ElevatedButton(
            child: Text((addToRepertoire ? "tracking" : "not tracking")),
            onPressed: () async {
              setState(() {
                addToRepertoire = !addToRepertoire;
              });
            },
          ),
        ]
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          ElevatedButton(
            child: const Text("Import"),
            onPressed: () async {
              var importer = await DataImport.create(dataAccess);
              await importer.importArchives();
              await importer.importAllGames();
              await importer.parseAllGames();
              print("imported");
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            child: const Text("Reset"),
            onPressed: () async {
              position = Chess.initial;
              var moveStats = await explorer.getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(position.fen), orientation == position.turn);
              var initShapes = makeMoveArrows(moveStats, position);
              for (var m in repertoireMoves) {
                var move = position.parseSan(m.move);
                var squares = move!.squares.toList();
                initShapes = initShapes.add(Arrow(
                  color: Colors.lightGreen.withAlpha(192),
                  orig: squares.first,
                  dest: squares.last,
                  scale: 0.6,
                ));
              }
              setState(() {
                lastPos = null;
                lastMove = null;
                fen = position.fen;
                sideToMove = Side.white;
                validMoves = makeLegalMoves(position);
                promotionMove = null;
                shapes = initShapes;
              });
            },
          ),
        ]
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          ElevatedButton(
            child: Text("Magnify drag: ${dragMagnify ? 'ON' : 'OFF'}"),
            onPressed: () {
              setState(() {
                dragMagnify = !dragMagnify;
              });
            },
          ),

          const SizedBox(width: 8),
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
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          ElevatedButton(
            child: Text('Orientation: ${orientation.name}'),
            onPressed: () {
              setState(() {
                orientation = orientation.opposite;
              });
            },
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
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
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
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
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
          const SizedBox(width: 8),
          ElevatedButton(
            child: Text("Show border: ${showBorder ? 'ON' : 'OFF'}"),
            onPressed: () {
              setState(() {
                showBorder = !showBorder;
              });
            },
          ),
        ],
      ),
        Center(
            child: IconButton(
                onPressed: lastPos != null
                    ? () => setState(() {
                  position = lastPos!;
                  fen = position.fen;
                  validMoves = makeLegalMoves(position);
                  lastPos = null;
                })
                    : null,
                icon: const Icon(Icons.chevron_left_sharp))),
    ];

    return Scaffold(
      appBar: AppBar(
          title: const Text('Free Play')
      ),
      drawer: Drawer(
          child: ListView(
            children: const [
              Text("derp."),
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
    validMoves = makeLegalMoves(position);

    explorer.getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(position.fen), orientation == position.turn).then((List<MoveStat> moveStats) {
      var initShapes = makeMoveArrows(moveStats, position);
        shapes = initShapes;
      });
    super.initState();
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
        color: (m.repo ? Colors.orangeAccent : Colors.lightGreen).withAlpha(128+(64*m.score).round()),
        orig: squares.first,
        dest: squares.last,
        scale: 0.2 + 0.8 * (m.count / max),
      ));
    }
    return newShapes;
  }

  Future<void> _playMove(NormalMove move, {bool? isDrop, bool? isPremove}) async {
    var sanMove = position.makeSan(move).$2;
    lastPos = position;
    if (isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else if (position.isLegal(move)) {
      await explorer.addMove(ChessHelper.stripMoveClockInfoFromFEN(lastPos!.fen), sanMove, ChessHelper.stripMoveClockInfoFromFEN(position.fen));
      var newPosition = position.playUnchecked(move);
      var moveStats = await explorer.getMoveStats(ChessHelper.stripMoveClockInfoFromFEN(newPosition.fen),orientation == newPosition.turn);
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
}