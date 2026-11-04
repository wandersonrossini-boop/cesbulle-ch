import 'package:flutter_test/flutter_test.dart';
import 'package:tesouraria_cme_app/domain/envelope.dart';
import 'package:tesouraria_cme_app/presentation/blocs/service_closing_events_states.dart';

void main() {
  group('Reconciliation Logic Tests - Etapa 2', () {
    test('Calculates cash and electronic separately and compares physical only with cash', () {
      // Exemplo da especificação:
      // Dinheiro registrado: CHF 350 (35000 rappen)
      // TWINT: CHF 100 (10000 rappen)
      // Transferências: CHF 50 (5000 rappen)
      // Total geral: CHF 500 (50000 rappen)
      // Dinheiro contado: CHF 350 (35000 rappen)
      // Diferença de caixa: CHF 0

      final state = ServiceClosingState(
        identifiedEntries: const [
          Envelope(
            id: '1',
            memberName: 'Membro 1',
            type: EnvelopeType.dizimo,
            amount: 20000, // CHF 200 em dinheiro
            paymentMethod: PaymentMethod.dinheiro,
          ),
          Envelope(
            id: '2',
            memberName: 'Membro 2',
            type: EnvelopeType.oferta,
            amount: 10000, // CHF 100 em TWINT
            paymentMethod: PaymentMethod.twint,
          ),
          Envelope(
            id: '3',
            memberName: 'Membro 3',
            type: EnvelopeType.voto,
            amount: 5000, // CHF 50 em Transferência bancária
            paymentMethod: PaymentMethod.transferencia,
          ),
        ],
        anonymousEntries: const [
          AnonymousEntry(
            id: '4',
            type: EnvelopeType.oferta,
            amount: 15000, // CHF 150 em dinheiro
            paymentMethod: PaymentMethod.dinheiro,
          ),
        ],
        physicalTotal: 35000, // CHF 350 contados na mesa
      );

      expect(state.totalDinheiro, equals(35000));
      expect(state.totalTwint, equals(10000));
      expect(state.totalTransferencias, equals(5000));
      expect(state.totalEletronico, equals(15000));
      expect(state.registeredTotal, equals(50000));
      expect(state.physicalTotal, equals(35000));
      // Diferença de caixa compara APENAS dinheiro físico com dinheiro registrado:
      expect(state.difference, equals(0));
    });

    test('Difference is non-zero when physical cash does not match registered cash', () {
      final state = ServiceClosingState(
        identifiedEntries: const [
          Envelope(
            id: '1',
            memberName: 'Membro 1',
            type: EnvelopeType.dizimo,
            amount: 20000, // CHF 200 em dinheiro
            paymentMethod: PaymentMethod.dinheiro,
          ),
          Envelope(
            id: '2',
            memberName: 'Membro 2',
            type: EnvelopeType.oferta,
            amount: 10000, // CHF 100 em TWINT
            paymentMethod: PaymentMethod.twint,
          ),
        ],
        anonymousEntries: const [
          AnonymousEntry(
            id: '3',
            type: EnvelopeType.oferta,
            amount: 15000, // CHF 150 em dinheiro
            paymentMethod: PaymentMethod.dinheiro,
          ),
        ],
        physicalTotal: 30000, // CHF 300 contados (falta 50 de dinheiro)
      );

      expect(state.totalDinheiro, equals(35000));
      expect(state.totalTwint, equals(10000));
      expect(state.totalEletronico, equals(10000));
      expect(state.registeredTotal, equals(45000));
      expect(state.difference, equals(-5000)); // CHF -50.00
    });
  });
}
