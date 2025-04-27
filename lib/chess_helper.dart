class ChessHelper {
  static String stripMoveClockInfoFromFEN(String fen) {
    var strippedFen = fen;
    var lastSpace = strippedFen.lastIndexOf(" ");
    strippedFen = strippedFen.substring(0, lastSpace);
    lastSpace = strippedFen.lastIndexOf(" ");
    strippedFen = strippedFen.substring(0, lastSpace);
    return strippedFen;
  }

  static String addFakeMoveClockInfoToFen(String fen) {
    return "$fen 0 1";
  }
}