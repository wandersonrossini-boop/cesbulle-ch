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

    @BeforeEach
    public void setUp() {
        expenseRepository = mock(ExpenseRepository.class);
        expenseAttachmentRepository = mock(ExpenseAttachmentRepository.class);
        storageService = mock(StorageService.class);
        controller = new ExpenseController(expenseRepository, expenseAttachmentRepository, storageService);

        authentication = mock(Authentication.class);
        when(authentication.getName()).thenReturn("admin");
        doReturn(Collections.singletonList(new SimpleGrantedAuthority("ROLE_ADMIN")))
                .when(authentication).getAuthorities();
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
}
