package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.DocumentType;
import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.ExpenseAttachment;
import com.tesourariacme.api.infrastructure.ExpenseAttachmentRepository;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.StorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.io.IOException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class ExpenseControllerTest {

    private ExpenseRepository expenseRepository;
    private ExpenseAttachmentRepository expenseAttachmentRepository;
    private StorageService storageService;
    private ExpenseController controller;
    private Authentication authentication;
    private Authentication adminAuth;
    private Authentication treasurerAuth;

    @BeforeEach
    public void setUp() {
        expenseRepository = mock(ExpenseRepository.class);
        expenseAttachmentRepository = mock(ExpenseAttachmentRepository.class);
        storageService = mock(StorageService.class);
        controller = new ExpenseController(expenseRepository, expenseAttachmentRepository, storageService);

        // Admin authentication mock
        adminAuth = mock(Authentication.class);
        when(adminAuth.getName()).thenReturn("admin");
        doReturn(Collections.singletonList(new SimpleGrantedAuthority("ROLE_ADMIN")))
                .when(adminAuth).getAuthorities();

        // Treasurer authentication mock (non-admin)
        treasurerAuth = mock(Authentication.class);
        when(treasurerAuth.getName()).thenReturn("treasurer");
        doReturn(Collections.singletonList(new SimpleGrantedAuthority("ROLE_TREASURER")))
                .when(treasurerAuth).getAuthorities();

        // Default authentication for existing tests (admin)
        authentication = adminAuth;
    }

    @Test
    public void testUploadAttachmentSuccess() throws IOException {
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");

        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));
        when(expenseAttachmentRepository.save(any(ExpenseAttachment.class))).thenAnswer(invocation -> {
            ExpenseAttachment attachment = invocation.getArgument(0);
            attachment.setId(10L);
            return attachment;
        });

        MockMultipartFile file = new MockMultipartFile(
                "file", "fatura.pdf", "application/pdf", "%PDF-1.4 ...".getBytes()
        );

        ResponseEntity<?> response = controller.uploadAttachment(1L, file, DocumentType.INVOICE, authentication);

        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertNotNull(response.getBody());
        ExpenseAttachment result = (ExpenseAttachment) response.getBody();
        assertEquals("fatura.pdf", result.getFileName());
        assertEquals("application/pdf", result.getContentType());
        verify(storageService, times(1)).save(anyString(), eq(file));
    }

    @Test
    public void testUploadAttachmentBlocksForReversed() throws IOException {
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("REVERSED");

        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        MockMultipartFile file = new MockMultipartFile(
                "file", "fatura.pdf", "application/pdf", "pdf bytes".getBytes()
        );

        ResponseEntity<?> response = controller.uploadAttachment(1L, file, DocumentType.INVOICE, authentication);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals("Não é permitido adicionar anexos a despesas rejeitadas ou estornadas.", response.getBody());
    }

    @Test
    public void testUploadAttachmentRejectsUnsupportedFormat() throws IOException {
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");

        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        MockMultipartFile file = new MockMultipartFile(
                "file", "malicious.exe", "application/x-msdownload", "exe bytes".getBytes()
        );

        ResponseEntity<?> response = controller.uploadAttachment(1L, file, DocumentType.INVOICE, authentication);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals("Formato de arquivo não suportado. Apenas PDF, JPG, JPEG e PNG.", response.getBody());
    }

    @Test
    public void testDeactivateAttachmentSuccess() {
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");

        ExpenseAttachment attachment = new ExpenseAttachment();
        attachment.setId(10L);
        attachment.setExpense(expense);
        attachment.setActive(true);

        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));
        when(expenseAttachmentRepository.findByIdAndExpenseId(10L, 1L)).thenReturn(Optional.of(attachment));
        when(expenseAttachmentRepository.save(any(ExpenseAttachment.class))).thenAnswer(inv -> inv.getArgument(0));

        DeactivationRequest request = new DeactivationRequest();
        request.setJustification("Enviado errado");

        ResponseEntity<?> response = controller.deactivateAttachment(1L, 10L, request, authentication);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        ExpenseAttachment result = (ExpenseAttachment) response.getBody();
        assertFalse(result.isActive());
        assertEquals("admin", result.getDeactivatedBy());
        assertEquals("Enviado errado", result.getDeactivationJustification());
    }

    @Test
    public void testDeactivateAttachmentBlocksForApprovedExpense() {
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("APPROVED");

        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        DeactivationRequest request = new DeactivationRequest();
        request.setJustification("Justificativa");

        ResponseEntity<?> response = controller.deactivateAttachment(1L, 10L, request, authentication);

        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertEquals("Apenas despesas PENDENTES podem ter anexos desativados.", response.getBody());
    }

    @Test
    public void testDownloadAttachmentSuccess() throws IOException {
        ExpenseAttachment attachment = new ExpenseAttachment();
        attachment.setId(10L);
        attachment.setFileName("comprovante.png");
        attachment.setContentType("image/png");
        attachment.setStoragePath("expenses/1/path.png");
        attachment.setActive(true);

        when(expenseAttachmentRepository.findByIdAndExpenseId(10L, 1L)).thenReturn(Optional.of(attachment));
        byte[] mockData = "png bytes".getBytes();
        when(storageService.load("expenses/1/path.png")).thenReturn(mockData);

        ResponseEntity<?> response = controller.downloadAttachment(1L, 10L);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("image/png", response.getHeaders().getFirst("Content-Type"));
        assertArrayEquals(mockData, (byte[]) response.getBody());
    }

    // ---------------------------------------------------------------------
    // Reversal endpoint – 6 explicit scenarios (D1-B3a)
    // ---------------------------------------------------------------------

    // Scenario 1: ADMIN + APPROVED + valid justification → 200 OK
    @Test
    public void reverseAdminApprovedValidJustification() {
        ReversalRequest request = new ReversalRequest();
        request.setJustification("Justificativa válida");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("APPROVED");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));
        when(expenseRepository.save(any(Expense.class))).thenAnswer(inv -> inv.getArgument(0));

        ResponseEntity<?> response = controller.reverseExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(expenseRepository, times(1)).save(any(Expense.class));
        // Audit field assertions
        assertEquals("REVERSED", expense.getStatus());
        assertEquals("Justificativa válida", expense.getReversalJustification());
        assertEquals("admin", expense.getReversedBy());
        assertNotNull(expense.getReversalDate());
    }

    // Scenario 2: TREASURER + APPROVED + valid justification → 403 Forbidden
    @Test
    public void reverseTreasurerForbidden() {
        ReversalRequest request = new ReversalRequest();
        request.setJustification("Justificativa válida");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("APPROVED");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.reverseExpense(1L, request, treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // Scenario 3: ADMIN + PENDING → 400 Bad Request (wrong status)
    @Test
    public void reverseAdminPendingBadRequest() {
        ReversalRequest request = new ReversalRequest();
        request.setJustification("Justificativa válida");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.reverseExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // Scenario 4: ADMIN + REJECTED → 400 Bad Request
    @Test
    public void reverseAdminRejectedBadRequest() {
        ReversalRequest request = new ReversalRequest();
        request.setJustification("Justificativa válida");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("REJECTED");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.reverseExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // Scenario 5: ADMIN + REVERSED → 400 Bad Request
    @Test
    public void reverseAdminReversedBadRequest() {
        ReversalRequest request = new ReversalRequest();
        request.setJustification("Justificativa válida");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("REVERSED");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.reverseExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // Scenario 6: ADMIN + APPROVED + empty justification → 400 Bad Request
    @Test
    public void reverseAdminEmptyJustificationBadRequest() {
        ReversalRequest request = new ReversalRequest();
        request.setJustification("   ");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("APPROVED");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.reverseExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // ---------------------------------------------------------------------
    // Rejection endpoint – audit assertions (D1-B3b-2)
    // ---------------------------------------------------------------------

    // ADMIN + PENDING + valid justification → 200 OK + audit fields set
    @Test
    public void rejectAdminPendingValidJustification() {
        RejectionRequest request = new RejectionRequest();
        request.setJustification("Motivo de rejeição");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));
        when(expenseRepository.save(any(Expense.class))).thenAnswer(inv -> inv.getArgument(0));

        ResponseEntity<?> response = controller.rejectExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        verify(expenseRepository, times(1)).save(any(Expense.class));
        // Audit assertions
        assertEquals("REJECTED", expense.getStatus());
        assertEquals("Motivo de rejeição", expense.getRejectionJustification());
        assertEquals("admin", expense.getRejectedBy());
        assertNotNull(expense.getRejectionDate());
    }

    // TREASURER + PENDING → 403 Forbidden, save never called
    @Test
    public void rejectTreasurerForbidden() {
        RejectionRequest request = new RejectionRequest();
        request.setJustification("Motivo");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.rejectExpense(1L, request, treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // ADMIN + PENDING + empty justification → 400, save never called
    @Test
    public void rejectAdminEmptyJustificationBadRequest() {
        RejectionRequest request = new RejectionRequest();
        request.setJustification("   ");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.rejectExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // ADMIN + PENDING + null justification → 400 Bad Request, no save
    @Test
    public void rejectAdminNullJustificationBadRequest() {
        RejectionRequest request = new RejectionRequest(); // justification left null
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.rejectExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    // ADMIN + PENDING + empty string justification → 400 Bad Request, no save
    @Test
    public void rejectAdminEmptyStringJustificationBadRequest() {
        RejectionRequest request = new RejectionRequest();
        request.setJustification("");
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus("PENDING");
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));

        ResponseEntity<?> response = controller.rejectExpense(1L, request, adminAuth);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        verify(expenseRepository, never()).save(any(Expense.class));
    }

    @Test
    public void testStatusTransitionMatrix() {
        // Matriz de Testes 1 a 12:
        
        // 1. PENDING -> APPROVED = ACEITA
        checkTransition("PENDING", "approve", HttpStatus.OK);
        // 2. PENDING -> REJECTED = ACEITA
        checkTransition("PENDING", "reject", HttpStatus.OK);
        // 3. PENDING -> REVERSED = REJEITA
        checkTransition("PENDING", "reverse", HttpStatus.BAD_REQUEST);
        
        // 4. APPROVED -> APPROVED = REJEITA
        checkTransition("APPROVED", "approve", HttpStatus.BAD_REQUEST);
        // 5. APPROVED -> REJECTED = REJEITA
        checkTransition("APPROVED", "reject", HttpStatus.BAD_REQUEST);
        // 6. APPROVED -> REVERSED = ACEITA
        checkTransition("APPROVED", "reverse", HttpStatus.OK);
        
        // 7. REJECTED -> APPROVED = REJEITA
        checkTransition("REJECTED", "approve", HttpStatus.BAD_REQUEST);
        // 8. REJECTED -> REJECTED = REJEITA
        checkTransition("REJECTED", "reject", HttpStatus.BAD_REQUEST);
        // 9. REJECTED -> REVERSED = REJEITA
        checkTransition("REJECTED", "reverse", HttpStatus.BAD_REQUEST);
        
        // 10. REVERSED -> APPROVED = REJEITA
        checkTransition("REVERSED", "approve", HttpStatus.BAD_REQUEST);
        // 11. REVERSED -> REJECTED = REJEITA
        checkTransition("REVERSED", "reject", HttpStatus.BAD_REQUEST);
        // 12. REVERSED -> REVERSED = REJEITA
        checkTransition("REVERSED", "reverse", HttpStatus.BAD_REQUEST);
    }

    private void checkTransition(String initialStatus, String action, HttpStatus expectedStatus) {
        Expense expense = new Expense();
        expense.setId(1L);
        expense.setStatus(initialStatus);

        reset(expenseRepository);
        when(expenseRepository.findById(1L)).thenReturn(Optional.of(expense));
        when(expenseRepository.save(any(Expense.class))).thenAnswer(inv -> inv.getArgument(0));

        ResponseEntity<?> response;
        if ("approve".equals(action)) {
            response = controller.approveExpense(1L, authentication);
        } else if ("reject".equals(action)) {
            RejectionRequest rejReq = new RejectionRequest();
            rejReq.setJustification("Justificativa de rejeição");
            response = controller.rejectExpense(1L, rejReq, authentication);
        } else { // reverse
            ReversalRequest request = new ReversalRequest();
            request.setJustification("Justificativa de estorno");
            response = controller.reverseExpense(1L, request, authentication);
        }

        assertEquals(expectedStatus, response.getStatusCode(),
                "Erro ao testar transição de " + initialStatus + " via ação " + action);
        if (!HttpStatus.OK.equals(expectedStatus)) {
            // ensure no persistence on rejected scenarios
            verify(expenseRepository, never()).save(any(Expense.class));
        }
    }
}
