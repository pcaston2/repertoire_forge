import 'package:dartchess/dartchess.dart';

import 'chess_helper.dart';

class GameExplorer {
  late Position _initialPosition;
  PgnNode<PgnNodeData> _root = PgnNode<PgnNodeData>();
  final List<String> _moveList = [];
  GameExplorer() {
    _initialPosition = Position.initialPosition(Rule.chess);
  }

  GameExplorer.fromFen(String fen) {
    _initialPosition = Chess.fromSetup(Setup.parseFen(fen));
  }

  String get fen => ChessHelper.stripMoveClockInfoFromFEN(position.fen);

  bool get hasAMove => getMoves().isNotEmpty;
  bool get isAtInitial => _moveList.isEmpty;
  String get lastMove => _moveList.last;

  Position get position {
    var currentNode = _root;
    var currentPosition = _initialPosition;
    for (var s in _moveList) {
      currentNode = getChildBySan(currentNode, s);
      var move = currentPosition.parseSan(s)!;
      currentPosition = currentPosition.play(move);
    }
    return currentPosition;
  }

  PgnNode<PgnNodeData> get _currentNode {
    var currentNode = _root;
    for (var s in _moveList) {
      currentNode = getChildBySan(currentNode, s);
    }
    return currentNode;
  }

  PgnNode<PgnNodeData> getChildBySan(PgnNode<PgnNodeData> node, String san) {
    return node.children.where((n) => n.data.san == san).single;
  }

  void move(String san) {
    if (!hasMove(san)) {
      var newNode = PgnChildNode<PgnNodeData>(PgnNodeData(san: san));
      _currentNode.children.add(newNode);
    }
    _moveList.add(san);
  }

  bool hasMove(String san) {
    return getMoves().any((m) => m == san);
  }

  List<String> getMoves() {
    return _currentNode.children.map((n) => n.data.san).toList();
  }

  back() {
    _moveList.removeLast();
  }

  String forward() {
    if (hasAMove) {
      var firstMove = getMoves().first;
      move(firstMove);
      return firstMove;
    } else {
      return "";
    }
  }

  String peek() {
    if (hasAMove) {
      return getMoves().first;
    } else {
      return "";
    }
  }

  reset() {
    _moveList.clear();
  }

  void end() {
    while (hasAMove) {
      forward();
    }
  }

  GameExplorer.fromPgn(String pgn) {
    var pgnGame = PgnGame.parsePgn(pgn);
    _initialPosition = PgnGame.startingPosition(pgnGame.headers);
    _root = pgnGame.moves;
  }

}