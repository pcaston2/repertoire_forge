import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'game_explorer.dart';

class OpeningTrainer extends StatefulWidget {
  const OpeningTrainer({super.key, required this.title, required this.pgn, required this.isWhite});

  final String title;
  final String pgn;
  final bool isWhite;

  @override
  State<OpeningTrainer> createState() => _OpeningTrainerState(pgn, isWhite);
}

class _OpeningTrainerState extends State<OpeningTrainer> with SingleTickerProviderStateMixin  {
  late Side orientation;
  String fen = kInitialBoardFEN;
  NormalMove? lastMove;
  NormalMove? promotionMove;
  ValidMoves validMoves = IMap(const {});
  late Side sideToMove;
  late bool isWhite;
  PieceSet pieceSet = PieceSet.gioco;
  PieceShiftMethod pieceShiftMethod = PieceShiftMethod.either;
  DragTargetKind dragTargetKind = DragTargetKind.circle;
  bool drawMode = true;
  bool pieceAnimation = true;
  bool dragMagnify = true;
  GameExplorer gameExplorer = GameExplorer();
  late GameExplorer path;
  ISet<Shape> shapes = ISet();
  bool showBorder = false;
  late AnimationController controller;
  late String pgn;

  _OpeningTrainerState(this.pgn, this.isWhite);

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
            },
            tooltip: "Rotate board",
          ),
          const Spacer(),
          IconButton(
            onPressed: !gameExplorer.isAtInitial ? () async {
              shapes = ISet<Shape>();
              gameExplorer.reset();
              path.reset();
              lastMove = null;
              await refresh();
            } : null,
            icon: const Icon(Icons.first_page_sharp),
            tooltip: "Go to first move",
          ),
          IconButton(
            onPressed: !gameExplorer.isAtInitial
                ? ()  async {
              shapes = ISet<Shape>();
              gameExplorer.back();
              path.back();
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
              shapes = ISet<Shape>();
              gameExplorer.forward();
              path.forward();
              lastMove = null;
              await refresh();
            }
                : null,
            icon: const Icon(Icons.chevron_right_sharp),
            tooltip: "Go to next move",
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              var move = path.position.parseSan(path.peek());
              var hintTile = move!.squares.first;
              Circle highlight = Circle(color: Colors.blueAccent, orig: hintTile);
              ISet<Shape> newShapes = ISet<Shape>();
              newShapes = newShapes.add(highlight);
              setState(() {
                shapes = newShapes;
              });
            },
            icon: const Icon(Icons.lightbulb_sharp),
            tooltip: "Hint",
          ),
          IconButton(
              onPressed: () {
                var move = path.position.parseSan(path.peek());
                Arrow solution = Arrow(color: Colors.blueAccent, orig: move!.squares.first, dest: move.squares.last);
                ISet<Shape> newShapes = ISet<Shape>();
                newShapes = newShapes.add(solution);
                setState(() {
                  shapes = newShapes;
                });
              },
              tooltip: "Solution",
              icon: const Icon(Icons.help_sharp)
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.redo_sharp),
            tooltip: "Skip",
          ),
          const Spacer(),
        ],
      ),
      const Divider(),
      ElevatedButton(
        style: path.hasAMove ? null : ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
        child: Text(path.hasAMove ? "Cancel" : "Continue"),
        onPressed: () {
          Navigator.pop(context, !path.hasAMove);
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
          title: const Text("Opening Trainer")
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
            shapes: shapes,
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
              playerSide: (path.hasAMove ? (isWhite? PlayerSide.white : PlayerSide.black) : PlayerSide.none),
              validMoves: validMoves,
              sideToMove: (isWhite ? Side.white : Side.black),
              isCheck: gameExplorer.position.isCheck,
              promotionMove: promotionMove,
              onMove: _playMove,
              onPromotionSelection: _onPromotionSelection,
            ),
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
    setState(() {
      fen = gameExplorer.fen;
      validMoves = makeLegalMoves(gameExplorer.position);
    });
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
    orientation = (isWhite ? Side.white : Side.black);
    sideToMove = (isWhite ? Side.white : Side.black);
    path = GameExplorer.fromPgn(pgn);
    controller = AnimationController(
      duration: const Duration(seconds: 0),
      value: 1,
      vsync: this,
    );

    validMoves = makeLegalMoves(gameExplorer.position);
    if (!isWhite) {
      makeComputerMove();
    }
  }

  void _onPromotionSelection(Role? role) {
    if (role == null) {
      _onPromotionCancel();
    } else if (promotionMove != null) {

    }
  }

  void _onPromotionCancel() {
    setState(() {
      promotionMove = null;
    });
  }

  Future<void> _playMove(NormalMove move, {bool? isDrop, bool? isPremove}) async {
    var sanMove = gameExplorer.position.makeSan(move).$2;
    if (path.peek() != sanMove) {
      var failArrow = Arrow(color: Colors.redAccent, orig: move.squares.first, dest: move.squares.last, scale: 0.5);
      var newShapes = ISet<Shape>();
      newShapes = newShapes.add(failArrow);
      setState(() {
        shapes = newShapes;
      });
      return;
    } else {
      shapes = ISet<Shape>();
    }
    if (isPromotionPawnMove(move)) {
      setState(() {
        promotionMove = move;
      });
    } else if (gameExplorer.position.isLegal(move)) {
      gameExplorer.move(sanMove);
      path.forward();
      setState(() {
        lastMove = move;
        fen = gameExplorer.fen;
        validMoves = makeLegalMoves(gameExplorer.position);
        promotionMove = null;
      });
      if (path.hasAMove) {
        makeComputerMove();

      }
    }
  }

  void makeComputerMove() {
    Future.delayed(const Duration(milliseconds: 100), () {
      var opponentMoveSan = path.forward();
      var opponentMove = gameExplorer.position.parseSan(opponentMoveSan)! as NormalMove;
      gameExplorer.move(opponentMoveSan);
      setState(() {
        lastMove = opponentMove;
        fen = gameExplorer.fen;
        validMoves = makeLegalMoves(gameExplorer.position);
        promotionMove = null;
      });
    });
  }

  bool isPromotionPawnMove(NormalMove move) {
    return move.promotion == null &&
        gameExplorer.position.board.roleAt(move.from) == Role.pawn &&
        ((move.to.rank == Rank.first && gameExplorer.position.turn == Side.black) ||
            (move.to.rank == Rank.eighth && gameExplorer.position.turn == Side.white));
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

}