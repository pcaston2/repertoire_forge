import 'package:dartchess/dartchess.dart';
import 'package:repertoire_forge/chess_tactics_extension.dart';
import 'package:test/test.dart';

void main() {
  test('should find check one check', () {
    //arrange
    var fen = "rnbqkbnr/ppppp1pp/8/5p2/4P3/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var result = sut.checks;
    //assert
    expect(result, hasLength(1));
    expect(result.single.toString(), contains("d1h5"));
  });

  test('should find check two checks', () {
    //arrange
    var fen = "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var result = sut.checks;
    //assert
    expect(result, hasLength(2));
  });

  test('should find promotion check with knight', () {
    //arrange
    var fen = "8/5k1P/8/8/8/5pp1/7p/7K w - - 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var result = sut.checks;
    //assert

    expect(result, hasLength(1));
    expect(result.single.toString(), contains("h7h8n"));
  });

  test('should find a capture', () {
    //arrange
    var fen = "3k4/8/8/3p4/4P3/8/8/3K4 w - - 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var results = sut.captures;
    //assert
    expect(results, hasLength(1));
    expect(results.single.toString(), contains("e4d5"));
  });

  test('should find a promotion capture to knight', () {
    //arrange
    var fen = "3k1n2/6P1/8/8/8/8/8/3K4 w - - 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var results = sut.captures;
    //assert
    expect(results, hasLength(4));
    expect(results,
        contains(predicate<NormalMove>((m) => m.toString().contains("g7f8n"))));
  });


  test('should find a capture on e4', () {
    //arrange
    var fen = "3k4/8/8/3p4/4P3/8/8/3K4 w - - 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var results = sut.capturesFrom(Square.e4);
    //assert
    expect(results, hasLength(1));
    expect(results.single.toString(), contains("e4d5"));
  });

  test('should find a promotion capture to knight on g7', () {
    //arrange
    var fen = "3k1n2/6P1/8/8/8/8/8/3K4 w - - 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var results = sut.capturesFrom(Square.g7);
    //assert
    expect(results, hasLength(4));
    expect(results,
        contains(predicate<NormalMove>((m) => m.toString().contains("g7f8n"))));
  });

  test('should find an attack', () {
    //arrange
    var fen = "3k4/8/3p4/8/4P3/8/8/3K4 w - - 0 1";
    var sut = Chess.fromSetup(Setup.parseFen(fen));
    //act
    var results = sut.attacks;
    //assert
    expect(results, hasLength(1));
    expect(results.single.toString(), contains("e4e5"));
  });
}