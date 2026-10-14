import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tesouraria_cme_app/services/contributor_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'jwt_token': 'test_token'});
  });

  group('ContributorModel and NPA validation tests', () {
    bool validateNPA(String zip) {
      final npa = int.tryParse(zip);
      return npa != null && npa >= 1000 && npa <= 9999 && zip.length == 4;
    }

    test('Valid Swiss NPAs pass validation', () {
      expect(validateNPA('1000'), isTrue);
      expect(validateNPA('1003'), isTrue); // Lausanne
      expect(validateNPA('1004'), isTrue); // Lausanne
      expect(validateNPA('1630'), isTrue); // Bulle
      expect(validateNPA('9999'), isTrue);
    });

    test('Invalid Swiss NPAs fail validation', () {
      expect(validateNPA(''), isFalse);
      expect(validateNPA('999'), isFalse); // 3 digits
      expect(validateNPA('0999'), isFalse); // below 1000
      expect(validateNPA('10000'), isFalse); // 5 digits
      expect(validateNPA('ABCD'), isFalse); // non-numeric
      expect(validateNPA('10 0'), isFalse); // spaces
    });

    test('ContributorModel serializes and deserializes all Swiss fiscal fields', () {
      final model = ContributorModel(
        id: '42',
        fullName: 'Jean Dupont',
        address: 'Rue de la Gare 10',
        postalCode: '1003',
        city: 'Lausanne',
        email: 'jean.dupont@example.ch',
        phone: '+41 79 123 45 67',
        contributorNumber: 'CH-LS-042',
        active: true,
        hasMovements: true,
      );

      final json = model.toJson();
      expect(json['id'], 42);
      expect(json['fullName'], 'Jean Dupont');
      expect(json['address'], 'Rue de la Gare 10');
      expect(json['postalCode'], '1003');
      expect(json['city'], 'Lausanne');
      expect(json['email'], 'jean.dupont@example.ch');
      expect(json['phone'], '+41 79 123 45 67');
      expect(json['contributorNumber'], 'CH-LS-042');
      expect(json['active'], isTrue);

      final reconstructed = ContributorModel.fromJson({
        'id': 42,
        'fullName': 'Jean Dupont',
        'address': 'Rue de la Gare 10',
        'postalCode': '1003',
        'city': 'Lausanne',
        'email': 'jean.dupont@example.ch',
        'phone': '+41 79 123 45 67',
        'contributorNumber': 'CH-LS-042',
        'active': true,
        'hasMovements': true,
      });

      expect(reconstructed.id, '42');
      expect(reconstructed.fullName, 'Jean Dupont');
      expect(reconstructed.postalCode, '1003');
      expect(reconstructed.city, 'Lausanne');
      expect(reconstructed.contributorNumber, 'CH-LS-042');
      expect(reconstructed.active, isTrue);
      expect(reconstructed.hasMovements, isTrue);
    });

    test('ContributorModel serializes null contributorNumber when empty for auto-generation', () {
      final model = ContributorModel(
        id: '',
        fullName: 'Marc Favre',
        address: 'Avenue de la Gare 1',
        postalCode: '1000',
        city: 'Lausanne',
        email: '',
        phone: '',
        contributorNumber: '   ',
        active: true,
      );

      final json = model.toJson();
      expect(json['id'], isNull);
      expect(json['fullName'], 'Marc Favre');
      expect(json['contributorNumber'], isNull);
    });

    test('createContributor accepts HTTP 200 response', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/contributors');
        return http.Response(
          jsonEncode({
            'id': 10,
            'fullName': 'Marc Favre',
            'contributorNumber': 'LS-001',
            'address': 'Avenue de la Gare 1',
            'postalCode': '1000',
            'city': 'Lausanne',
            'active': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ContributorApiService(client: mockClient);
      final model = ContributorModel(
        id: '',
        fullName: 'Marc Favre',
        address: 'Avenue de la Gare 1',
        postalCode: '1000',
        city: 'Lausanne',
        email: '',
        phone: '',
        contributorNumber: '',
        active: true,
      );

      final result = await service.createContributor(model);
      expect(result.id, '10');
      expect(result.contributorNumber, 'LS-001');
    });

    test('createContributor accepts HTTP 201 response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 11,
            'fullName': 'Claire Dupont',
            'contributorNumber': 'LS-002',
            'address': 'Rue du Pont 5',
            'postalCode': '1003',
            'city': 'Lausanne',
            'active': true,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ContributorApiService(client: mockClient);
      final model = ContributorModel(
        id: '',
        fullName: 'Claire Dupont',
        address: 'Rue du Pont 5',
        postalCode: '1003',
        city: 'Lausanne',
        email: '',
        phone: '',
        contributorNumber: '',
        active: true,
      );

      final result = await service.createContributor(model);
      expect(result.id, '11');
      expect(result.contributorNumber, 'LS-002');
    });

    test('createContributor sanitizes validation error from JSON message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Número do contribuinte já cadastrado.'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ContributorApiService(client: mockClient);
      final model = ContributorModel(
        id: '',
        fullName: 'Claire Dupont',
        address: 'Rue du Pont 5',
        postalCode: '1003',
        city: 'Lausanne',
        email: '',
        phone: '',
        contributorNumber: 'LS-001',
        active: true,
      );

      expect(
        () => service.createContributor(model),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Número do contribuinte já cadastrado.'),
        )),
      );
    });

    test('createContributor does not expose internal stack traces on 500 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          'Internal Server Error: org.postgresql.util.PSQLException: at com.tesourariacme.api...',
          500,
        );
      });

      final service = ContributorApiService(client: mockClient);
      final model = ContributorModel(
        id: '',
        fullName: 'Claire Dupont',
        address: 'Rue du Pont 5',
        postalCode: '1003',
        city: 'Lausanne',
        email: '',
        phone: '',
        contributorNumber: '',
        active: true,
      );

      expect(
        () => service.createContributor(model),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          isNot(contains('org.postgresql.util.PSQLException')),
        )),
      );
    });
  });
}
