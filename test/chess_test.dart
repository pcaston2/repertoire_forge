import 'package:dartchess/dartchess.dart';
import 'package:test/test.dart';
import 'package:repertoire_forge/chess_helper.dart';

void main() {
  test('Import FEN', () async {
    //arrange
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    //act
    var setup = Setup.parseFen(fen);
    var sut = Chess.fromSetup(setup);
    //assert
    expect(sut.fen, equals(fen), reason: "The position should match");
  });

  test('Strip position info from FEN', () async {
    //arrange
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    var expected = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
    //act
    var strippedFen = ChessHelper.stripMoveClockInfoFromFEN(fen);
    //assert
    expect(expected, equals(strippedFen), reason: "Should remove move info");
  });

  test('parse pgn', () async {
    //arrange
    var pgn = "[Event \"Live Chess\"]\n[Site \"Chess.com\"]\n[Date \"2025.01.03\"]\n[Round \"-\"]\n[White \"pcaston2\"]\n[Black \"Kare71\"]\n[Result \"1-0\"]\n[CurrentPosition \"rnb1kbnr/ppN2ppp/3pq3/4P3/3P1p2/5N2/PPP3PP/R1BQKB1R b KQkq -\"]\n[Timezone \"UTC\"]\n[ECO \"C28\"]\n[ECOUrl \"https://www.chess.com/openings/Vienna-Game-Falkbeer-Vienna-Gambit\"]\n[UTCDate \"2025.01.03\"]\n[UTCTime \"05:31:44\"]\n[WhiteElo \"890\"]\n[BlackElo \"885\"]\n[TimeControl \"180+2\"]\n[Termination \"pcaston2 won by resignation\"]\n[StartTime \"05:31:44\"]\n[EndDate \"2025.01.03\"]\n[EndTime \"05:33:14\"]\n[Link \"https://www.chess.com/game/live/121886201912\"]\n\n1. e4 {[%clk 0:03:01.9]} 1... e5 {[%clk 0:03:00.4]} 2. Nc3 {[%clk 0:03:03.2]} 2... Nf6 {[%clk 0:03:00.4]} 3. f4 {[%clk 0:03:03.7]} 3... exf4 {[%clk 0:02:55.4]} 4. e5 {[%clk 0:03:04.4]} 4... Ng8 {[%clk 0:02:51.2]} 5. Nf3 {[%clk 0:03:03.4]} 5... Qe7 {[%clk 0:02:41.5]} 6. d4 {[%clk 0:02:32.9]} 6... d6 {[%clk 0:02:37.6]} 7. Nd5 {[%clk 0:02:33.5]} 7... Qe6 {[%clk 0:02:36]} 8. Nxc7+ {[%clk 0:02:32.6]} 1-0\n";
    var expectedFen = "rnb1kbnr/ppN2ppp/3pq3/4P3/3P1p2/5N2/PPP3PP/R1BQKB1R b KQkq - 0 8";
    int moveCount = 1;
    //act
    final game = PgnGame.parsePgn(pgn);
    Position position = PgnGame.startingPosition(game.headers);
    for (final node in game.moves.mainline()) {
      moveCount++;
      final move = position.parseSan(node.san)!;
      position = position.play(move);
    }
    //assert
    expect(moveCount, equals(16), reason: "The PGN move number should match");
    expect(position.fen, equals(expectedFen));
  });

  test('test en passent', () async {
    //arrange
    var pgn = "1. e4 Na6 2. e5 d5";
    var expectedFen = "r1bqkbnr/ppp1pppp/n7/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3";
    //act
    final game = PgnGame.parsePgn(pgn);
    Position position = PgnGame.startingPosition(game.headers);
    String fen = position.fen;
    for (final node in game.moves.mainline()) {
      final move = position.parseSan(node.san)!;
      position = position.play(move);
      fen = position.fen;
    }
    //assert
    expect(fen, equals(expectedFen));
  });

  test('build a pgn', () async {
    //arrange
    var expectedPgn = "1. e4 ( 1. d4 d5 ) 1... e5 *\n";
    var root = PgnNode<PgnNodeData>();
    var e4 = PgnChildNode<PgnNodeData>(PgnNodeData(san: "e4"));
    var d4 = PgnChildNode<PgnNodeData>(PgnNodeData(san: "d4"));
    root.children.add(e4);
    root.children.add(d4);
    d4.children.add(PgnChildNode<PgnNodeData>(PgnNodeData(san: "d5")));
    e4.children.add(PgnChildNode<PgnNodeData>(PgnNodeData(san: "e5")));
    //act
    var pgn = PgnGame(headers: <String, String>{}, moves: root, comments: <String>[]);
    //assert
    expect(pgn.makePgn(), equals(expectedPgn));
  });

  test('nodes are different', () {
    //arrange
    var node1 = PgnChildNode<PgnNodeData>(PgnNodeData(san: "e4"));
    var node2 = PgnChildNode<PgnNodeData>(PgnNodeData(san: "e4"));
    //assert
    expect(node1, isNot(equals(node2)));
  });

  test('should generate valid move', () {
    //arrange
    var fen = "r1bqk2r/pppp1ppp/2n2n2/4p3/1bB1P3/2NP4/PPP1NPPP/R1BQK2R b - - 2 5";
    var san = "O-O";
    var setup = Setup.parseFen(fen);
    var sut = Chess.fromSetup(setup);
    //act
    var move = sut.parseSan(san);
    //assert
    expect(move, isNotNull);
  });
}