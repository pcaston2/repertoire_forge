import 'package:dartchess/dartchess.dart';

Set<Role> promotable = {Role.knight, Role.bishop, Role.rook, Role.queen};

extension ChessTacticsExtension on Position {

  bool isPromoting(NormalMove m) {
    return board.roleAt(m.from) == Role.pawn &&
        ((m.to.rank == Rank.first && turn == Side.black) ||
            (m.to.rank == Rank.eighth && turn == Side.white));
  }

  List<NormalMove> get checks {
    List<NormalMove> checkMoves = [];
    var moves = legalMoves;
    for (var squares in moves.entries) {
      bool hasCheck(NormalMove m) {
        var newPos = play(m);
        return newPos.isCheck;
      }
      var from = squares.key;
      for (var to in squares.value.squares) {
        var move = NormalMove(from: from, to: to);
        if (isPromoting(move)) {
          for (var role in promotable) {
            var promotionMove = move.withPromotion(role);
            if (hasCheck(promotionMove)) {
              checkMoves.add(promotionMove);
            }
          }
        } else {
          if (hasCheck(move)) {
            checkMoves.add(move);
          }
        }
      }
    }
    return checkMoves;
  }

  List<NormalMove> get captures {
    var enemySquares = (turn == Side.white ? board.black : board.white);
    List<NormalMove> captureMoves = [];
    for (var to in enemySquares.squares) {
      var attackers = board.attacksTo(to, turn);
      for (var from in attackers.squares) {
        var move = NormalMove(from: from, to: to);
        if (isPromoting(move)) {
          for (var role in promotable) {
            var promotionMove = move.withPromotion(role);
            captureMoves.add(promotionMove);
          }
        } else {
          captureMoves.add(move);
        }
      }
    }
    return captureMoves;
  }

  List<NormalMove> capturesFrom(Square from) {
    List<NormalMove> captures = [];
    var toSquares = legalMoves.entry(from).value;
    if (toSquares == null) {
      return captures;
    }
    var caps = toSquares.intersect(enemySquares);
    for (var capture in caps.squares) {
      var move = NormalMove(from: from, to: capture);
      if (isPromoting(move)) {
        for (var role in promotable) {
          var promotionMove = move.withPromotion(role);
          captures.add(promotionMove);
        }
      } else {
        captures.add(move);
      }
    }
    return captures;
  }

  List<NormalMove> get attacks {
    List<NormalMove> attackMoves = [];
    var moves = legalMoves;
    for (var squares in moves.entries) {
      var from = squares.key;
      for (var to in squares.value.squares) {
        var move = NormalMove(from: from, to: to);
        var newPos = play(move).flipSide();
        if (newPos.capturesFrom(to).isNotEmpty) {
          attackMoves.add(move);
        }
      }
    }
    return attackMoves;
  }

  Position flipSide() {
    var setup = new Setup(
                      board: board,
                      turn: (turn == Side.white ? Side.black : Side.white),
                      castlingRights: castles.castlingRights,
                      halfmoves: halfmoves,
                      fullmoves: fullmoves );
    var flippedPosition = Position.setupPosition(Rule.chess, setup);
    return flippedPosition;
  }

  SquareSet get enemySquares => turn == Side.white ? board.black : board.white;
  SquareSet get friendlySquares => turn == Side.white ? board.white : board.black;
}