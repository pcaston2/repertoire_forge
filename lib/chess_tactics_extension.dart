import 'package:dartchess/dartchess.dart';


extension ChessMoveTacticsExtension on NormalMove {
  static Set<Role> promotable = {Role.knight, Role.bishop, Role.rook, Role.queen};

  List<NormalMove> get promotions {
    List<NormalMove> moves = [];
    for (var role in promotable) {
      moves.add(withPromotion(role));
    }
    return moves;
  }
}

extension ChessRoleTacticsExtension on Role {
  int get value {
    switch (this) {

      case Role.pawn:
        return 1;
      case Role.knight:
      case Role.bishop:
        return 3;
      case Role.rook:
        return 5;
      case Role.king:
        return 30;
      case Role.queen:
        return 9;
    }
  }
}

extension ChessPromotionTacticsExtension on Position {

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
          for (var promotionMove in move.promotions) {
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
          for (var promotionMove in move.promotions) {
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
        for (var promotionMove in move.promotions) {
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
    var caps = captures;

    bool hasACaptureNextTurn(var move) {
      var newPos = play(move);
      var flip = newPos.flipSide();
      var newCaps = flip.capturesFrom(move.to)
          .where((nextMove) => board.roleAt(nextMove.to) != Role.king && flip.captureChain(nextMove.to) > 0)
          .map((c) => NormalMove(from: move.from, to: c.to))
          .where((dm) => !caps.contains(dm));
      return newCaps.isNotEmpty;
    }

    var moves = legalMoves;
    for (var squares in moves.entries) {
      var from = squares.key;
      for (var to in squares.value.squares) {
        var move = NormalMove(from: from, to: to);
        if (isPromoting(move)) {
          for (var promotionMove in move.promotions) {
            if (hasACaptureNextTurn(promotionMove)) {
              attackMoves.add(promotionMove);
            }
          }
        } else {
          if (hasACaptureNextTurn(move)) {
            attackMoves.add(move);
          }
        }
      }
    }
    return attackMoves;
  }

  Position flipSide() {
    var flippedPosition = copyWith(turn: (turn == Side.white ? Side.black : Side.white));
    return flippedPosition;
  }


  int captureChain(Square square, {Side? attacker}) {
    attacker ??= turn;
    int? bestChain;
    var pieceAtSquare = board.roleAt(square);
    if (pieceAtSquare == null) {
      throw Exception("No piece at capture chain square");
    }
    var pieceSideModifier = (attacker == turn ? 1 : -1);
    var pieceValue = pieceAtSquare.value * pieceSideModifier;
    var attackers = board.attacksTo(square, turn).squares;
    for (var a in attackers) {
      int? currChain;
      var move = NormalMove(from: a, to: square);
      if (isLegal(move)) {
        if (isPromoting(move)) {
          for (var promotionMove in move.promotions) {
            var promotionValue = (promotionMove.promotion!.value - 1) * pieceSideModifier;
            var newPos = play(promotionMove);
            currChain = newPos.captureChain(square, attacker: attacker) + promotionValue;
            bestChain ??= currChain;
            if (attacker == turn ? currChain > bestChain : currChain < bestChain) {
              bestChain = currChain;
            }
          }
        } else {
          var newPos = play(move);
          var currChain = newPos.captureChain(square, attacker: attacker);
          bestChain ??= currChain;
          if (attacker == turn ? currChain > bestChain : currChain < bestChain) {
            bestChain = currChain;
          }
        }
      }
    }
    return (bestChain == null ? 0 : bestChain + pieceValue);
  }

  SquareSet get enemySquares => turn == Side.white ? board.black : board.white;
  SquareSet get friendlySquares => turn == Side.white ? board.white : board.black;
}