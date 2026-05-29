import 'package:flutter_test/flutter_test.dart';
import 'package:vido_foody_flutter/main.dart';

void main() {
  testWidgets('Vido Foody POS app loads', (tester) async {
    await tester.pumpWidget(const VidoFoodyApp());
    expect(find.text('Sell'), findsOneWidget);
  });
}
