import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:stockfish_chess_engine/stockfish.dart';
import 'package:stockfish_chess_engine/stockfish_state.dart';

class Engine {
  late Stockfish stockfish;
  late final StreamSubscription<String> output;
  final Function(EngineInfo) callback;
  int depth = 40;
  EngineState state = EngineState.starting;
  String latestMove = "";

  factory Engine.create(Function(EngineInfo) callback) {
    var engine = Engine._instance(callback);
    engine.warmUp();

    return engine;
  }

  Engine._instance(this.callback) {
    stockfish = Stockfish();
    output = stockfish.stdout.listen((message) {
      parseOutput(message);
    });
  }

  void setPosition(String fen) {
    stockfish.stdin = 'stop';
    stockfish.stdin = 'position fen $fen';
    stockfish.stdin = 'go depth $depth';
  }

  Future<void> warmUp() async {
    while (state == EngineState.starting) {
      await Future.delayed(const Duration(seconds: 1));
      switch (stockfish.state.value) {
        case StockfishState.error:
          state = EngineState.error;
          throw Exception("Stockfish broken");
        case StockfishState.ready:
          state = EngineState.running;
        default:
          continue;
      }
    }
  }




  /*
// Get Stockfish ready
  stockfish.stdin = 'isready';

// Send you commands to Stockfish stdin
  stockfish.stdin = 'position startpos'; // set up start position
  //stockfish.stdin = 'position fen rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2'; // set up custom position
  stockfish.stdin = 'go movetime 1500'; // search move for at most 1500ms

   */


  @override
  void dispose() {
    output.cancel();
    stockfish.dispose();
  }

  void parseOutput(String message) {
    var split = message.split(" ");
    var header = split.first;
    switch (header) {
      case "info":
        var regex = RegExp(r'.*depth (?<depth>\d+) multipv (?<multipv>\d+) score cp (?<score>\-?\d+).*? pv(?<pv>(?: (?:[a-h][1-8]){2})+)');
        var match = regex.firstMatch(message);
        if (match != null) {
          var info = EngineInfo();
          info.depth = int.parse(match.namedGroup('depth')!);
          info.multipv = int.parse(match.namedGroup('multipv')!);
          info.score = int.parse(match.namedGroup('score')!);
          info.principalVariation = match.namedGroup('pv')!.split(" ").where((pv) => pv.isNotEmpty).toList();
          print(info.principalVariation);
          callback.call(info);
        }
        break;
    }
  }
}

class EngineInfo {
  int? depth;
  int? seldepth;
  int? multipv;
  int? score;
  int? win;
  int? draw;
  int? lose;
  List<String> principalVariation = [];
}

enum EngineState {
  starting,
  running,
  error,
}