import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/game_explorer.dart';


void main() {
  test('Get initial game position', () async {
    //arrange
    var sut = GameExplorer();
    //act
    var result = sut.fen;
    //assert
    expect(result, equals("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"));
  });

  test('Make a move', () async {
    //arrange
    var sut = GameExplorer();
    //act
    sut.move("e4");
    var fen = sut.fen;
    //assert
    expect(fen, equals("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -"));
  });

  test('Back up', () async {
    //arrange
    var sut = GameExplorer();
    sut.move("e4");
    //act
    sut.back();
    var fen = sut.fen;
    //assert
    expect(fen, equals("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"));
  });

  test('load from pgn', () async {
    //arrange
    var sut = GameExplorer.fromPgn("1. e4 ( 1. d4 ) *\n");
    //act
    var moves = sut.getMoves();
    //assert
    expect(moves, contains("e4"));
    expect(moves, contains("d4"));
  });
}