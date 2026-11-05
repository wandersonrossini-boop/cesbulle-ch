package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.ExpenseAttachment;
import com.tesourariacme.api.infrastructure.ExpenseAttachmentRepository;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.StorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.time.LocalDate;
import java.util.Collections;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ExpenseGovernanceFourEyesTest {

    private ExpenseRepository expenseRepository;
    private ExpenseAttachmentRepository expenseAttachmentRepository;
    private StorageService storageService;
    private com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService;
    private com.tesourariacme.api.application.AuditLogService auditLogService;
    private ExpenseController controller;

    private Authentication creatorAuth;
    private Authentication approverAuth;
    private Authentication payerAuth;

    @BeforeEach
    void setUp() {
        expenseRepository = mock(ExpenseRepository.class);
        expenseAttachmentRepository = mock(ExpenseAttachmentRepository.class);
        storageService = mock(StorageService.class);
        monthlyPeriodService = mock(com.tesourariacme.api.application.MonthlyPeriodService.class);
        auditLogService = mock(com.tesourariacme.api.application.AuditLogService.class);

        when(monthlyPeriodService.isPeriodLocked(any(LocalDate.class))).thenReturn(false);
        controller = new ExpenseController(expenseRepository, expenseAttachmentRepository, storageService, monthlyPeriodService, auditLogService);

        creatorAuth = mock(Authentication.class);
        when(creatorAuth.getName()).thenReturn("pastor");
        doReturn(Collections.singletonList(new SimpleGrantedAuthority("ROLE_ADMIN"))).when(creatorAuth).getAuthorities();

        approverAuth = mock(Authentication.class);
        when(approverAuth.getName()).thenReturn("dimi");
        doReturn(Collections.singletonList(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(approverAuth).getAuthorities();

        payerAuth = mock(Authentication.class);
        when(payerAuth.getName()).thenReturn("lima");
        doReturn(Collections.singletonList(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(payerAuth).getAuthorities();
    }

    @Test
    @DisplayName("Regra 1: Criador NÃO pode aprovar a própria despesa")
    void testCreatorCannotApproveOwnExpense() {
        Expense expense = new Expense();
        expense.setId(10L);
        expense.setStatus("PENDING");
        expense.setCreatedBy("pastor");

        when(expenseRepository.findById(10L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.approveExpense(10L, creatorAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("não pode aprovar o próprio lançamento"));
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    @Test
    @DisplayName("Regra 2: Outro usuário autorizado PODE aprovar a despesa")
    void testDifferentUserCanApproveExpense() {
        Expense expense = new Expense();
        expense.setId(10L);
        expense.setStatus("PENDING");
        expense.setCreatedBy("pastor");

        when(expenseRepository.findById(10L)).thenReturn(Optional.of(expense));
        when(expenseRepository.save(any(Expense.class))).thenAnswer(inv -> inv.getArgument(0));

        ResponseEntity<?> response = controller.approveExpense(10L, approverAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("APPROVED", expense.getStatus());
        assertEquals("dimi", expense.getApprovedBy());
        assertNotNull(expense.getApprovalDate());
    }

    @Test
    @DisplayName("Regra 3: Criador NÃO pode pagar a própria despesa")
    void testCreatorCannotPayOwnExpense() {
        Expense expense = new Expense();
        expense.setId(10L);
        expense.setStatus("APPROVED");
        expense.setCreatedBy("pastor");
        expense.setApprovedBy("dimi");

        ExpenseAttachment att = new ExpenseAttachment();
        att.setActive(true);
        expense.getAttachments().add(att);

        when(expenseRepository.findById(10L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.payExpense(10L, creatorAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("não pode registrar o pagamento"));
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    @Test
    @DisplayName("Regra 4: Aprovador NÃO pode registrar o pagamento da despesa que aprovou")
    void testApproverCannotPayApprovedExpense() {
        Expense expense = new Expense();
        expense.setId(10L);
        expense.setStatus("APPROVED");
        expense.setCreatedBy("pastor");
        expense.setApprovedBy("dimi");

        ExpenseAttachment att = new ExpenseAttachment();
        att.setActive(true);
        expense.getAttachments().add(att);

        when(expenseRepository.findById(10L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.payExpense(10L, approverAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertTrue(response.getBody().toString().contains("não pode registrar o pagamento"));
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    @Test
    @DisplayName("Regra 5: Terceiro usuário independente PODE registrar pagamento preservando approvedBy/approvalDate e preenchendo paidBy/paymentDate")
    void testThirdIndependentUserCanPayExpense() {
        Expense expense = new Expense();
        expense.setId(10L);
        expense.setStatus("APPROVED");
        expense.setCreatedBy("pastor");
        expense.setApprovedBy("dimi");
        expense.setApprovalDate(LocalDate.of(2026, 11, 1));

        ExpenseAttachment att = new ExpenseAttachment();
        att.setActive(true);
        expense.getAttachments().add(att);

        when(expenseRepository.findById(10L)).thenReturn(Optional.of(expense));
        when(expenseRepository.save(any(Expense.class))).thenAnswer(inv -> inv.getArgument(0));

        ResponseEntity<?> response = controller.payExpense(10L, payerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("PAID", expense.getStatus());
        assertEquals("dimi", expense.getApprovedBy()); // Preservado
        assertEquals(LocalDate.of(2026, 11, 1), expense.getApprovalDate()); // Preservado
        assertEquals("lima", expense.getPaidBy()); // Novo campo preenchido
        assertNotNull(expense.getPaymentDate()); // Data preenchida
    }
}
