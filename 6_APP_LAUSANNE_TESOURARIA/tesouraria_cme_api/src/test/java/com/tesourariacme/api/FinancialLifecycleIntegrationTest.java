package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.*;
import com.tesourariacme.api.domain.*;
import com.tesourariacme.api.infrastructure.*;
import com.tesourariacme.api.presentation.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@SpringBootTest
@org.springframework.boot.autoconfigure.EnableAutoConfiguration(
    exclude = {
        org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration.class,
        org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration.class,
        org.springframework.boot.autoconfigure.jdbc.DataSourceTransactionManagerAutoConfiguration.class
    }
)
public class FinancialLifecycleIntegrationTest {

    @Autowired
    private ContributorController contributorController;

    @Autowired
    private ServiceClosingController serviceClosingController;

    @Autowired
    private ExpenseController expenseController;

    @Autowired
    private FinancialReportController financialReportController;

    @MockBean
    private ContributorRepository contributorRepository;

    @MockBean
    private ServiceClosingRepository serviceClosingRepository;

    @MockBean
    private ExpenseRepository expenseRepository;

    @MockBean
    private MonthlyPeriodRepository monthlyPeriodRepository;

    @MockBean
    private AuditLogRepository auditLogRepository;

    @MockBean
    private MemberRepository memberRepository;

    @MockBean
    private EnvelopeRepository envelopeRepository;

    @MockBean
    private ExpenseAttachmentRepository expenseAttachmentRepository;

    @MockBean
    private StorageService storageService;

    @MockBean
    private RecurringExpenseRepository recurringExpenseRepository;

    @MockBean
    private ServiceClosingSessionRepository serviceClosingSessionRepository;

    @MockBean
    private ServiceScheduleRepository serviceScheduleRepository;

    @MockBean
    private AppUserRepository appUserRepository;

    @MockBean
    private javax.sql.DataSource dataSource;

    @Test
    public void testCompleteFinancialLifecycle() throws Exception {
        // Setup Auth
        Authentication adminAuth = mock(Authentication.class);
        when(adminAuth.getName()).thenReturn("admin");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))).when(adminAuth).getAuthorities();

        // 1. Register a contributor
        Contributor contributor = new Contributor();
        contributor.setId(1L);
        contributor.setFullName("John Doe");
        contributor.setContributorNumber("CONT-001");
        contributor.setActive(true);

        when(contributorRepository.save(any(Contributor.class))).thenReturn(contributor);
        ResponseEntity<?> contribResp = contributorController.create(contributor, adminAuth);
        assertEquals(HttpStatus.OK, contribResp.getStatusCode());

        // 2. Realizar fechamento de culto
        ServiceClosingRequest closingReq = new ServiceClosingRequest();
        closingReq.setServiceDate(LocalDate.now());
        closingReq.setMainTreasurer("Admin");
        closingReq.setVerifierName("Verifier");
        closingReq.setVerifierType(VerifierType.SELECTED);
        closingReq.setPhysicalTotal(BigDecimal.valueOf(100.0));

        EnvelopeRequest envReq = new EnvelopeRequest();
        envReq.setMemberName("John Doe");
        envReq.setType(EnvelopeType.DIZIMO);
        envReq.setAmount(BigDecimal.valueOf(100.0));
        closingReq.setIdentifiedEntries(List.of(envReq));

        ServiceClosing closing = new ServiceClosing();
        closing.setId(10L);
        closing.setServiceDate(LocalDate.now());
        closing.setMainTreasurer("Admin");
        closing.setVerifierName("Verifier");
        closing.setVerifierType(VerifierType.SELECTED);
        closing.setPhysicalTotal(BigDecimal.valueOf(100.0));
        closing.setTotalDizimos(BigDecimal.valueOf(100.0));
        closing.setTotalOfertas(BigDecimal.valueOf(0.0));
        closing.setTotalVotos(BigDecimal.valueOf(0.0));

        Envelope env = new Envelope(1L, "John Doe", EnvelopeType.DIZIMO, BigDecimal.valueOf(100.0));
        env.setContributorId(1L);
        closing.setIdentifiedEntries(List.of(env));

        // Stub locking check for closing submit
        when(monthlyPeriodRepository.findByYearAndMonth(anyInt(), anyInt())).thenReturn(Optional.empty());
        when(serviceClosingRepository.save(any(ServiceClosing.class))).thenReturn(closing);
        ResponseEntity<?> closingResp = serviceClosingController.submitClosing(closingReq);
        assertEquals(HttpStatus.OK, closingResp.getStatusCode());

        // 3. Lançar despesa e aprovar
        ExpenseRequest expenseReq = new ExpenseRequest();
        expenseReq.setExpenseDate(LocalDate.now());
        expenseReq.setAmount(BigDecimal.valueOf(50.0));
        expenseReq.setDescription("Aluguel");

        Expense expense = new Expense();
        expense.setId(100L);
        expense.setExpenseDate(LocalDate.now());
        expense.setAmount(BigDecimal.valueOf(50.0));
        expense.setStatus("PENDING");
        expense.setDescription("Aluguel");

        when(expenseRepository.save(any(Expense.class))).thenReturn(expense);
        when(expenseRepository.findById(100L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> expenseCreateResp = expenseController.createExpense(expenseReq, adminAuth);
        assertEquals(HttpStatus.OK, expenseCreateResp.getStatusCode(), () -> "Response Body: " + expenseCreateResp.getBody());

        ResponseEntity<?> approveResp = expenseController.approveExpense(100L, adminAuth);
        assertEquals(HttpStatus.OK, approveResp.getStatusCode());

        // 4. Consultar relatório contábil mensal
        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(closing));
        when(expenseRepository.findByExpenseDateBetweenAndStatusIn(any(LocalDate.class), any(LocalDate.class), anyList()))
                .thenReturn(List.of(expense));

        ResponseEntity<?> reportResp = financialReportController.getMonthlyReport(LocalDate.now().getMonthValue(), LocalDate.now().getYear(), adminAuth);
        assertEquals(HttpStatus.OK, reportResp.getStatusCode());
        FinancialReportDTO reportDto = (FinancialReportDTO) reportResp.getBody();
        assertNotNull(reportDto);
        assertEquals(BigDecimal.valueOf(100.0), reportDto.getSummary().getTotalIncomes());

        // 5. Executar trava do mês contábil
        MonthlyPeriod period = new MonthlyPeriod();
        period.setYear(LocalDate.now().getYear());
        period.setMonth(LocalDate.now().getMonthValue());
        period.setStatus(MonthlyPeriod.PeriodStatus.LOCKED);

        when(monthlyPeriodRepository.save(any(MonthlyPeriod.class))).thenReturn(period);
        
        // Return locked period when checking
        when(monthlyPeriodRepository.findByYearAndMonth(LocalDate.now().getYear(), LocalDate.now().getMonthValue()))
                .thenReturn(Optional.of(period));

        ResponseEntity<?> lockResp = financialReportController.lockMonthlyPeriod(LocalDate.now().getMonthValue(), LocalDate.now().getYear(), adminAuth);
        assertEquals(HttpStatus.OK, lockResp.getStatusCode());

        // 6. Tentar alterar fechamento/despesa e assegurar rejeição
        assertThrows(IllegalStateException.class, () -> serviceClosingController.submitClosing(closingReq));

        // 7. Emitir PDFs
        ResponseEntity<?> reportPdfResp = financialReportController.getMonthlyReportPdf(LocalDate.now().getMonthValue(), LocalDate.now().getYear(), adminAuth);
        assertEquals(HttpStatus.OK, reportPdfResp.getStatusCode());
        assertNotNull(reportPdfResp.getBody());

        // 8. Validar geração de logs
        verify(auditLogRepository, atLeastOnce()).save(any(AuditLog.class));
    }
}
