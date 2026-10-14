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

    test('InitializeClosingContextEvent registers authenticated mainTreasurer as 1st conferente', () async {
      bloc.add(InitializeClosingContextEvent(
        DateTime(2026, 10, 14),
        'Pastor',
        '',
        sessionId: 10,
        serviceTime: '19:00',
        serviceEndTime: '21:00',
        serviceType: 'Culto da Família',
      ));
      await Future.delayed(Duration.zero);

      expect(bloc.state.mainTreasurer, 'Pastor');
      expect(bloc.state.sessionId, 10);
      expect(bloc.state.serviceTime, '19:00');
    });

    test('SubmitClosingEvent preserves verifierName and verifierType for dupla conferência', () {
      final eventAuth = SubmitClosingEvent(verifierName: 'Admilson', verifierType: 'AUTHENTICATED');
      expect(eventAuth.verifierName, 'Admilson');
      expect(eventAuth.verifierType, 'AUTHENTICATED');

      final eventSel = SubmitClosingEvent(verifierName: 'João Silva', verifierType: 'SELECTED');
      expect(eventSel.verifierName, 'João Silva');
      expect(eventSel.verifierType, 'SELECTED');

      final eventMan = SubmitClosingEvent(verifierName: 'Conferente Manual', verifierType: 'MANUAL');
      expect(eventMan.verifierName, 'Conferente Manual');
      expect(eventMan.verifierType, 'MANUAL');
    });

    test('MergeSessionDraftEvent merges entries by ID without duplicates and sums totals', () async {
      // 1st treasurer enters an envelope
      bloc.add(AddEnvelopeEvent(const Envelope(id: 'env-1', memberName: 'Membro 1', type: EnvelopeType.dizimo, amount: 10000, enteredBy: 'Pastor')));
      await Future.delayed(Duration.zero);

      expect(bloc.state.identifiedEntries.length, 1);
      expect(bloc.state.registeredTotal, 10000);

      // 2nd treasurer on another device added another envelope and an offering in server draft
      final serverState = ServiceClosingState(
        identifiedEntries: const [
          Envelope(id: 'env-1', memberName: 'Membro 1', type: EnvelopeType.dizimo, amount: 10000, enteredBy: 'Pastor'),
          Envelope(id: 'env-2', memberName: 'Membro 2', type: EnvelopeType.oferta, amount: 20000, enteredBy: 'Admilson'),
        ],
        anonymousEntries: const [
          AnonymousEntry(id: 'anon-1', type: EnvelopeType.oferta, amount: 5000, enteredBy: 'Admilson'),
        ],
        conferente1Ready: true,
        conferente2Ready: false,
        conferente2: 'Admilson',
      );

      bloc.add(MergeSessionDraftEvent(serverState));
      await Future.delayed(Duration.zero);

      // Verify no duplicates occurred on env-1 and totals correctly summed
      expect(bloc.state.identifiedEntries.length, 2);
      expect(bloc.state.anonymousEntries.length, 1);
      expect(bloc.state.identifiedTotal, 30000);
      expect(bloc.state.anonymousTotal, 5000);
      expect(bloc.state.registeredTotal, 35000);
      expect(bloc.state.conferente1Ready, true);
      expect(bloc.state.conferente2Ready, false);
      expect(bloc.state.conferente2, 'Admilson');
    });
  });
}
