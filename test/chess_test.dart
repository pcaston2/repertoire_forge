import 'package:chess/chess.dart';
import 'package:test/test.dart';
import 'package:repertoire_forge/chess_helper.dart';

void main() {
  test('Import FEN', () async {
    //arrange
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    //act
    var sut = Chess.fromFEN(fen);
    //assert
    expect(sut.fen, equals(fen), reason: "The position should match");
  });

  test('Strip position info from FEN', () async {
    //arrange
    var fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
    var expected = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -";
    //act
    var strippedFen = ChessHelper.StripMoveInfoFromFEN(fen);
    //assert
    expect(expected, equals(strippedFen), reason: "Should remove move info");
  });

  test('parse pgn', () async {
    //arrange
    var pgn = "[Event \"Live Chess\"]\n[Site \"Chess.com\"]\n[Date \"2025.01.03\"]\n[Round \"-\"]\n[White \"pcaston2\"]\n[Black \"Kare71\"]\n[Result \"1-0\"]\n[CurrentPosition \"rnb1kbnr/ppN2ppp/3pq3/4P3/3P1p2/5N2/PPP3PP/R1BQKB1R b KQkq -\"]\n[Timezone \"UTC\"]\n[ECO \"C28\"]\n[ECOUrl \"https://www.chess.com/openings/Vienna-Game-Falkbeer-Vienna-Gambit\"]\n[UTCDate \"2025.01.03\"]\n[UTCTime \"05:31:44\"]\n[WhiteElo \"890\"]\n[BlackElo \"885\"]\n[TimeControl \"180+2\"]\n[Termination \"pcaston2 won by resignation\"]\n[StartTime \"05:31:44\"]\n[EndDate \"2025.01.03\"]\n[EndTime \"05:33:14\"]\n[Link \"https://www.chess.com/game/live/121886201912\"]\n\n1. e4 {[%clk 0:03:01.9]} 1... e5 {[%clk 0:03:00.4]} 2. Nc3 {[%clk 0:03:03.2]} 2... Nf6 {[%clk 0:03:00.4]} 3. f4 {[%clk 0:03:03.7]} 3... exf4 {[%clk 0:02:55.4]} 4. e5 {[%clk 0:03:04.4]} 4... Ng8 {[%clk 0:02:51.2]} 5. Nf3 {[%clk 0:03:03.4]} 5... Qe7 {[%clk 0:02:41.5]} 6. d4 {[%clk 0:02:32.9]} 6... d6 {[%clk 0:02:37.6]} 7. Nd5 {[%clk 0:02:33.5]} 7... Qe6 {[%clk 0:02:36]} 8. Nxc7+ {[%clk 0:02:32.6]} 1-0\n";
    var expectedFen = "rnb1kbnr/ppN2ppp/3pq3/4P3/3P1p2/5N2/PPP3PP/R1BQKB1R b KQkq - 0 8";
    var sut = Chess();
    //act
    var result = sut.load_pgn(pgn);
    //assert
    expect(result, equals(true), reason: "should be able to parse pgn");
    expect(sut.move_number, equals(8), reason: "The PGN move number should match");
    expect(sut.fen, equals(expectedFen));
  });
}