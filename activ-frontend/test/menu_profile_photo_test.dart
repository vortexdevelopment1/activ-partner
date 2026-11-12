import 'package:activ_app/Screens/Menu/MenuScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'test-token'});
  });

  testWidgets('shows Add Profile Photo when avatar is not set', (tester) async {
    final client = MockClient((request) async {
      return http.Response(
          jsonEncode({
            'data': {
              'partner': {
                'id': 'partner-1',
                'firstName': 'John',
                'lastName': 'Doe',
                'email': 'john@example.com',
                'avatarUrl': '',
              }
            }
          }),
          200);
    });

    await tester.pumpWidget(MaterialApp(
      home: MenuScreen(client: client),
    ));
    await tester.pumpAndSettle();

    final editButton = find.byTooltip('Edit profile photo');
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Add Profile Photo'), findsOneWidget);
    expect(find.text('Change Profile Photo'), findsNothing);
    expect(find.text('Remove Profile Photo'), findsNothing);
  });

  testWidgets('shows Change Profile Photo and Remove Profile Photo when avatar is set', (tester) async {
    final client = MockClient((request) async {
      return http.Response(
          jsonEncode({
            'data': {
              'partner': {
                'id': 'partner-1',
                'firstName': 'John',
                'lastName': 'Doe',
                'email': 'john@example.com',
                'avatarUrl': 'https://example.com/photo.jpg',
              }
            }
          }),
          200);
    });

    await tester.pumpWidget(MaterialApp(
      home: MenuScreen(client: client),
    ));
    await tester.pumpAndSettle();

    final editButton = find.byTooltip('Edit profile photo');
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Change Profile Photo'), findsOneWidget);
    expect(find.text('Add Profile Photo'), findsNothing);
    expect(find.text('Remove Profile Photo'), findsOneWidget);
  });
}
