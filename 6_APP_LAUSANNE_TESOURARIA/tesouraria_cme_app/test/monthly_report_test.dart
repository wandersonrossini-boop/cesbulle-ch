import 'package:flutter_test/flutter_test.dart';
import 'package:tesouraria_cme_app/services/financial_report_api_service.dart';

void main() {
  group('MonthlyReportModel & PaymentMethodSummaryModel Tests - Etapa 5', () {
    test('Deserializes payment methods and calculates totals properly', () {
      final json = {
        'period': {'month': 10, 'year': 2026},
        'summary': {
          'totalIncomes': 500.0,
          'totalExpenses': 200.0,
          'totalCommitted': 50.0,
          'netBalance': 300.0,
        },
        'paymentMethods': {
          'totalDinheiro': 350.0,
          'totalTwint': 100.0,
          'totalTransferencias': 50.0,
          'totalEletronico': 150.0,
        },
        'incomesByCategory': [
          {'category': 'Dízimos Nominais', 'total': 350.0, 'count': 3},
          {'category': 'Ofertas', 'total': 150.0, 'count': 2},
        ],
        'expensesByCategory': [
          {'category': 'Aluguel', 'total': 200.0, 'count': 1},
        ],
        'metadata': {
          'status': 'LOCKED',
          'currency': 'CHF',
          'generatedAt': '2026-10-31T20:00:00',
        }
      };

      final report = MonthlyReportModel.fromJson(json);

      expect(report.month, 10);
      expect(report.year, 2026);
      expect(report.totalIncomes, 500.0);
      expect(report.totalExpenses, 200.0);
      expect(report.totalCommitted, 50.0);
      expect(report.netBalance, 300.0);
      expect(report.status, 'LOCKED');

      // Segregação por meio de recebimento
      expect(report.paymentMethods.totalDinheiro, 350.0);
      expect(report.paymentMethods.totalTwint, 100.0);
      expect(report.paymentMethods.totalTransferencias, 50.0);
      expect(report.paymentMethods.totalEletronico, 150.0);
      expect(
        report.paymentMethods.totalDinheiro + report.paymentMethods.totalEletronico,
        report.totalIncomes,
      );
    });
  });
}
