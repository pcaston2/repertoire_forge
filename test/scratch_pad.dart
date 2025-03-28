import 'package:flutter_test/flutter_test.dart';
import 'package:repertoire_forge/game_explorer.dart';
import 'package:repertoire_forge/task.dart';


void main() {
  test('complete tasks', () async {
    //arrange
    Stream<int> getSequence() async* {
      for (var i = 0; i<3;i++) {
        await Future.delayed(const Duration(milliseconds: 20));
        yield i;
      }
    }

    var sut = Task<int>(getSequence());
    //act
    await sut.start();
    //assert
    expect(sut.processedItems, equals(3));
  });

  test('cancelled tasks', () async {
    //arrange
    Stream<int> getSequence() async* {
      for (var i = 0; i<10;i++) {
        await Future.delayed(const Duration(seconds: 1));
        yield i;
      }
    }

    var sut = Task<int>(getSequence());
    //act
    sut.start();
    sut.cancel();
    //assert
    expect(sut.state, equals(TaskState.cancelled));
    expect(sut.processedItems, lessThan(10));
  });

  test('errored tasks', () async {
    //arrange
    Stream<int> getSequence() async* {
      for (var i = 0; i<10;i++) {
        await Future.delayed(const Duration(milliseconds: 20));
        if (i == 4) {
          throw Exception("Whoops!");
        }
        yield i;
      }
    }

    var sut = Task<int>(getSequence());
    //act
    await sut.start();
    //assert
    expect(sut.processedItems, lessThan(10));
    expect(sut.state, equals(TaskState.error));
    expect(sut.exception, isNotNull);
  });
}