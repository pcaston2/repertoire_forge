import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/eco_codes.dart';

void main() {
  test('Get info about the eco code', () async {
    //arrange
    var sut = EcoCodes();
    //act
    var ecoCode = sut.getFromFen(
        "rn1qkbnr/ppp2ppp/8/3pp3/5P2/6Pb/PPPPP2P/RNBQKB1R w KQkq -");
    //assert
    expect(ecoCode!.name, equals("Amar Opening: Paris Gambit"));
  });
}