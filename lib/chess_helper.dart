class ChessHelper {
  static String StripMoveInfoFromFEN(String fen) {
    var strippedFen = fen;
    var lastSpace = strippedFen.lastIndexOf(" ");
    strippedFen = strippedFen.substring(0, lastSpace);
    lastSpace = strippedFen.lastIndexOf(" ");
    strippedFen = strippedFen.substring(0, lastSpace);
    return strippedFen;
  }
}