package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.*;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.presentation.FinancialReportDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.anyList;

public class FinancialReportServiceTest {

    private ServiceClosingRepository serviceClosingRepository;
    private ExpenseRepository expenseRepository;
    private MonthlyPeriodService monthlyPeriodService;
    private FinancialReportService service;

    @BeforeEach
    public void setUp() {
        serviceClosingRepository = mock(ServiceClosingRepository.class);
        expenseRepository = mock(ExpenseRepository.class);
        monthlyPeriodService = mock(MonthlyPeriodService.class);
        service = new FinancialReportService(serviceClosingRepository, expenseRepository, monthlyPeriodService);
    }

    @Test
    public void testTithingSeparationIdentifiedVsUnidentified() {
        ServiceClosing closing = new ServiceClosing();
        closing.setServiceDate(LocalDate.of(2026, 8, 15));
        
        List<Envelope> envelopes = new ArrayList<>();
        envelopes.add(new Envelope(1L, "João", EnvelopeType.DIZIMO, BigDecimal.valueOf(150.00)));
        envelopes.add(new Envelope(2L, "Maria", EnvelopeType.OFERTA, BigDecimal.valueOf(50.00)));
        closing.setIdentifiedEntries(envelopes);
        
        closing.setUnidentifiedDizimoTotal(BigDecimal.valueOf(100.00));
        closing.setUnidentifiedOfertaTotal(BigDecimal.valueOf(30.00));
        closing.setUnidentifiedVotoTotal(BigDecimal.valueOf(10.00));
        closing.setPhysicalTotal(BigDecimal.valueOf(340.00)); // Set physicalTotal equal to registeredTotal (200 + 140)
        closing.calculateTotalsAndValidate();

        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(closing));
        when(expenseRepository.findByExpenseDateBetweenAndStatusIn(any(LocalDate.class), any(LocalDate.class), anyList()))
                .thenReturn(List.of());

        FinancialReportDTO report = service.generateMonthlyReport(8, 2026);

        // Verify incomes list details
        BigDecimal nominalDizimo = BigDecimal.ZERO;
        BigDecimal anonDizimo = BigDecimal.ZERO;
        for (FinancialReportDTO.CategorySummary income : report.getIncomesByCategory()) {
            if ("Dízimos Nominais (Identificados)".equals(income.getCategory())) {
                nominalDizimo = income.getTotal();
            } else if ("Dízimos Anônimos (Não Identificados)".equals(income.getCategory())) {
                anonDizimo = income.getTotal();
            }
        }
        assertEquals(0, BigDecimal.valueOf(150.00).compareTo(nominalDizimo));
        assertEquals(0, BigDecimal.valueOf(100.00).compareTo(anonDizimo));
        assertEquals(0, BigDecimal.valueOf(340.00).compareTo(report.getSummary().getTotalIncomes()));
    }

    @Test
    public void testApprovedDoesNotReduceNetBalanceAndGoesToTotalCommitted() {
        ServiceClosing closing = new ServiceClosing();
        closing.setServiceDate(LocalDate.of(2026, 8, 15));
        closing.setUnidentifiedOfertaTotal(BigDecimal.valueOf(500.00));
        closing.setPhysicalTotal(BigDecimal.valueOf(500.00)); // Set physicalTotal equal to registeredTotal (500)
        closing.calculateTotalsAndValidate();

        Expense approvedExpense = new Expense();
        approvedExpense.setId(1L);
        approvedExpense.setAmount(BigDecimal.valueOf(120.00));
        approvedExpense.setStatus("APPROVED");

        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(closing));
        
        // When checking for PAID expenses, return none
        when(expenseRepository.findByExpenseDateBetweenAndStatusIn(any(LocalDate.class), any(LocalDate.class), eq(List.of("PAID"))))
                .thenReturn(List.of());
        // When checking for APPROVED expenses, return the approvedExpense
        when(expenseRepository.findByExpenseDateBetweenAndStatusIn(any(LocalDate.class), any(LocalDate.class), eq(List.of("APPROVED"))))
                .thenReturn(List.of(approvedExpense));

        FinancialReportDTO report = service.generateMonthlyReport(8, 2026);

        assertEquals(0, BigDecimal.valueOf(500.00).compareTo(report.getSummary().getTotalIncomes()));
        assertEquals(0, BigDecimal.ZERO.compareTo(report.getSummary().getTotalExpenses()));
        assertEquals(0, BigDecimal.valueOf(120.00).compareTo(report.getSummary().getTotalCommitted()));
        assertEquals(0, BigDecimal.valueOf(500.00).compareTo(report.getSummary().getNetBalance())); // Not reduced
    }

    @Test
    public void testPaidReducesNetBalanceAndDoesNotGoToTotalCommitted() {
        ServiceClosing closing = new ServiceClosing();
        closing.setServiceDate(LocalDate.of(2026, 8, 15));
        closing.setUnidentifiedOfertaTotal(BigDecimal.valueOf(500.00));
        closing.setPhysicalTotal(BigDecimal.valueOf(500.00)); // Set physicalTotal equal to registeredTotal (500)
        closing.calculateTotalsAndValidate();

        Expense paidExpense = new Expense();
        paidExpense.setId(2L);
        paidExpense.setAmount(BigDecimal.valueOf(200.00));
        paidExpense.setStatus("PAID");
        paidExpense.setCategory("Serviços");

        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(closing));
        
        // When checking for PAID expenses, return the paidExpense
        when(expenseRepository.findByExpenseDateBetweenAndStatusIn(any(LocalDate.class), any(LocalDate.class), eq(List.of("PAID"))))
                .thenReturn(List.of(paidExpense));
        // When checking for APPROVED expenses, return none
        when(expenseRepository.findByExpenseDateBetweenAndStatusIn(any(LocalDate.class), any(LocalDate.class), eq(List.of("APPROVED"))))
                .thenReturn(List.of());

        FinancialReportDTO report = service.generateMonthlyReport(8, 2026);

        assertEquals(0, BigDecimal.valueOf(500.00).compareTo(report.getSummary().getTotalIncomes()));
        assertEquals(0, BigDecimal.valueOf(200.00).compareTo(report.getSummary().getTotalExpenses()));
        assertEquals(0, BigDecimal.ZERO.compareTo(report.getSummary().getTotalCommitted()));
        assertEquals(0, BigDecimal.valueOf(300.00).compareTo(report.getSummary().getNetBalance())); // Reduced
    }

    @Test
    public void testSegregationByPaymentMethod() {
        ServiceClosing closing = new ServiceClosing();
        closing.setServiceDate(LocalDate.of(2026, 8, 15));
        closing.setTotalDinheiro(new BigDecimal("350.00"));
        closing.setTotalTwint(new BigDecimal("100.00"));
        closing.setTotalTransferencias(new BigDecimal("50.00"));
        closing.setTotalEletronico(new BigDecimal("150.00"));

        List<Envelope> envelopes = new ArrayList<>();
        Envelope e1 = new Envelope();
        e1.setType(EnvelopeType.DIZIMO);
        e1.setAmount(new BigDecimal("350.00"));
        e1.setPaymentMethod(PaymentMethod.DINHEIRO);
        envelopes.add(e1);

        Envelope e2 = new Envelope();
        e2.setType(EnvelopeType.OFERTA);
        e2.setAmount(new BigDecimal("100.00"));
        e2.setPaymentMethod(PaymentMethod.TWINT);
        envelopes.add(e2);

        Envelope e3 = new Envelope();
        e3.setType(EnvelopeType.VOTO);
        e3.setAmount(new BigDecimal("50.00"));
        e3.setPaymentMethod(PaymentMethod.TRANSFERENCIA);
        envelopes.add(e3);

        closing.setIdentifiedEntries(envelopes);

        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(closing));
        when(expenseRepository.findByExpenseDateBetweenAndStatusIn(any(LocalDate.class), any(LocalDate.class), anyList()))
                .thenReturn(List.of());

        FinancialReportDTO report = service.generateMonthlyReport(8, 2026);

        assertNotNull(report.getPaymentMethods());
        assertEquals(0, new BigDecimal("350.00").compareTo(report.getPaymentMethods().getTotalDinheiro()));
        assertEquals(0, new BigDecimal("100.00").compareTo(report.getPaymentMethods().getTotalTwint()));
        assertEquals(0, new BigDecimal("50.00").compareTo(report.getPaymentMethods().getTotalTransferencias()));
        assertEquals(0, new BigDecimal("150.00").compareTo(report.getPaymentMethods().getTotalEletronico()));
        assertEquals(0, new BigDecimal("500.00").compareTo(report.getSummary().getTotalIncomes()));
    }
}
