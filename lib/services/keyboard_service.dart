import 'package:kurdle_app/domain.dart';

class KeyboardService {
  final List<List<Letter>> _keys;

  List<List<Letter>> get keys => _keys;

  KeyboardService._(this._keys);

  static Letter _toLetter(String letter) {
    return Letter(value: letter, isKey: true);
  }

  static KeyboardService init({ KeyboardLayout keyboardLayout = KeyboardLayout.qwerty }) {
    // Kurmancî keyboard layout
    return KeyboardService._(<List<Letter>>[
      <String>['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'Û', 'I', 'Î', 'O', 'P'].map((l) => _toLetter(l)).toList(),
      <String>['A', 'S', 'Ş', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ê'].map((l) => _toLetter(l)).toList(),
      <String>['ENTER', 'Z', 'X', 'C', 'Ç', 'V', 'B', 'N', 'M', 'BACK'].map((l) => _toLetter(l)).toList()
    ]);
  }

  static bool isEnter(String letter) => letter == 'ENTER';
  static bool isBackspace(String letter) => letter == 'BACK';
}
