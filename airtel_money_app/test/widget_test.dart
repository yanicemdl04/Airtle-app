import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airtel_money/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Affiche l\'écran de connexion au démarrage', (tester) async {
    await tester.pumpWidget(const AirtelMoneyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('airtel money'), findsOneWidget);
  });
}
