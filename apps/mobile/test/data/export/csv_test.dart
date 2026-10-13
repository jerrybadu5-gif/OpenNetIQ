import 'package:flutter_test/flutter_test.dart';
import 'package:opennetiq_mobile/data/export/csv.dart';

void main() {
  test('nulls are empty, never zero', () {
    expect(
      csvRow([null, 0, -88.5, true, false, double.nan]),
      ',0,-88.5,true,false,',
    );
  });

  test('quotes fields with comma, quote or line breaks', () {
    expect(csvField('Digicel, PNG'), '"Digicel, PNG"');
    expect(csvField('say "hi"'), '"say ""hi"""');
    expect(csvField('a\nb'), '"a\nb"');
    expect(csvField('plain'), 'plain');
  });

  test('document uses CRLF and a header', () {
    expect(
      csvDocument(
        ['a', 'b'],
        [
          [1, null],
        ],
      ),
      'a,b\r\n1,\r\n',
    );
  });
}
