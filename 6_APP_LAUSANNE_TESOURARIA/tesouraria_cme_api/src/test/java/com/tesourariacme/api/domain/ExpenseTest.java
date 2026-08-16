package com.tesourariacme.api.domain;

import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;

public class ExpenseTest {

    @Test
    public void testExpensePropertiesAndAttachmentBinding() {
        Expense expense = new Expense();
        expense.setDescription("Aluguel do Templo");
        expense.setAmount(new BigDecimal("1800.00"));
        expense.setObservations("Pagamento em dia");

        ExpenseAttachment attachment = new ExpenseAttachment();
        attachment.setExpense(expense);
        attachment.setFileName("fatura.pdf");
        attachment.setDocumentType(DocumentType.INVOICE);
        attachment.setContentType("application/pdf");
        attachment.setFileSize(2048L);
        attachment.setStoragePath("expenses/1/abc.pdf");
        attachment.setUploadedBy("tesouraria");
        attachment.setUploadedAt(LocalDateTime.now());

        expense.getAttachments().add(attachment);

        assertEquals("Aluguel do Templo", expense.getDescription());
        assertEquals(new BigDecimal("1800.00"), expense.getAmount());
        assertEquals("Pagamento em dia", expense.getObservations());
        assertEquals(1, expense.getAttachments().size());
        
        ExpenseAttachment added = expense.getAttachments().get(0);
        assertEquals("fatura.pdf", added.getFileName());
        assertEquals(DocumentType.INVOICE, added.getDocumentType());
        assertEquals(expense, added.getExpense());
        assertTrue(added.isActive());
        assertNull(added.getDeactivatedBy());
        assertNull(added.getDeactivatedAt());
    }

    @Test
    public void testAttachmentDeactivationAudit() {
        ExpenseAttachment attachment = new ExpenseAttachment();
        assertTrue(attachment.isActive());
        
        attachment.setActive(false);
        attachment.setDeactivatedBy("pastor");
        attachment.setDeactivatedAt(LocalDateTime.now());
        attachment.setDeactivationJustification("Arquivo errado");

        assertFalse(attachment.isActive());
        assertEquals("pastor", attachment.getDeactivatedBy());
        assertEquals("Arquivo errado", attachment.getDeactivationJustification());
        assertNotNull(attachment.getDeactivatedAt());
    }
}
