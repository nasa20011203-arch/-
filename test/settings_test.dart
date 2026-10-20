import 'package:flutter_test/flutter_test.dart';
import 'package:offline_calendar/models/app_settings.dart';

void main() {
  test(
    'invalid settings are bounded and offscreen positions remain representable',
    () {
      final settings = AppSettings.fromJson({
        'width': -1,
        'height': 3,
        'x': -1200,
        'opacity': 10,
        'fontSize': double.nan,
      });
      expect(settings.width, 560);
      expect(settings.height, 420);
      expect(settings.x, -1200);
      expect(settings.opacity, 1);
      expect(settings.fontSize, 14);
    },
  );
}
