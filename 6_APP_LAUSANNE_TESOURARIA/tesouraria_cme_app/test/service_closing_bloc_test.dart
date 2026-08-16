import 'package:flutter_test/flutter_test.dart';
import 'package:tesouraria_cme_app/domain/envelope.dart';
import 'package:tesouraria_cme_app/presentation/blocs/service_closing_bloc.dart';
import 'package:tesouraria_cme_app/presentation/blocs/service_closing_events_states.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ServiceClosingBloc - Golden Test', () {
    late ServiceClosingBloc bloc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      bloc = ServiceClosingBloc();
    });

    tearDown(() {
      bloc.close();
    });

    test('Audit: Dízimo, Oferta, Voto and Undo logic', () async {
      // Dízimo identificado 100.00
      bloc.add(AddEnvelopeEvent(const Envelope(id: '1', type: EnvelopeType.dizimo, amount: 10000, memberName: 'A')));
      // Dízimo anônimo 20.00
      const da = AnonymousEntry(id: 'a1', type: EnvelopeType.dizimo, amount: 2000);
      bloc.add(AddAnonymousOfferingEvent(da));
      // Oferta identificada 50.00
      bloc.add(AddEnvelopeEvent(const Envelope(id: '2', type: EnvelopeType.oferta, amount: 5000, memberName: 'B')));
      // Oferta anônima 30.00
      const oa = AnonymousEntry(id: 'a2', type: EnvelopeType.oferta, amount: 3000);
      bloc.add(AddAnonymousOfferingEvent(oa));
      // Voto identificado 40.00
      bloc.add(AddEnvelopeEvent(const Envelope(id: '3', type: EnvelopeType.voto, amount: 4000, memberName: 'C')));
      // Voto anônimo 10.00
      const va = AnonymousEntry(id: 'a3', type: EnvelopeType.voto, amount: 1000);
      bloc.add(AddAnonymousOfferingEvent(va));

      // Físico 250.00
      bloc.add(SetPhysicalTotalEvent(25000));
      await Future.delayed(Duration.zero);

      expect(bloc.state.registeredTotal, 25000);
      expect(bloc.state.physicalTotal, 25000);
      expect(bloc.state.difference, 0);

      // Verify subtotals by category
      expect(bloc.state.identifiedTotalBy(EnvelopeType.dizimo), 10000);
      expect(bloc.state.anonymousTotalBy(EnvelopeType.dizimo), 2000);
      
      expect(bloc.state.identifiedTotalBy(EnvelopeType.oferta), 5000);
      expect(bloc.state.anonymousTotalBy(EnvelopeType.oferta), 3000);
      
      expect(bloc.state.identifiedTotalBy(EnvelopeType.voto), 4000);
      expect(bloc.state.anonymousTotalBy(EnvelopeType.voto), 1000);

      // Desfazer Voto anônimo CHF 10
      bloc.add(UndoAnonymousOfferingEvent(va.id));
      await Future.delayed(Duration.zero);

      expect(bloc.state.registeredTotal, 24000);
      expect(bloc.state.physicalTotal, 25000);
      expect(bloc.state.difference, 1000);
    });

    test('RestoreDraftEvent clears isSuccess, isSubmitting and error', () async {
      final dirtyState = ServiceClosingState(
        date: DateTime.now(),
        mainTreasurer: 'Admilson',
        isSuccess: true,
        isSubmitting: true,
        error: 'Some error',
      );

      bloc.add(RestoreDraftEvent(dirtyState));
      await Future.delayed(Duration.zero);

      expect(bloc.state.isSuccess, false);
      expect(bloc.state.isSubmitting, false);
      expect(bloc.state.error, null);
      expect(bloc.state.mainTreasurer, 'Admilson');
    });
  });
}
