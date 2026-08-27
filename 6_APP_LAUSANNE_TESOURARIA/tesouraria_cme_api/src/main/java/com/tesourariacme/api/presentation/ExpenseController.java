package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.DocumentType;
import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.ExpenseAttachment;
import com.tesourariacme.api.infrastructure.ExpenseAttachmentRepository;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.StorageService;
import lombok.Data;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/despesas")
public class ExpenseController {

    private final ExpenseRepository expenseRepository;
    private final ExpenseAttachmentRepository expenseAttachmentRepository;
    private final StorageService storageService;
    private final com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService;
    private final com.tesourariacme.api.application.AuditLogService auditLogService;

    public ExpenseController(
            ExpenseRepository expenseRepository,
            ExpenseAttachmentRepository expenseAttachmentRepository,
            StorageService storageService,
            com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService,
            com.tesourariacme.api.application.AuditLogService auditLogService) {
        this.expenseRepository = expenseRepository;
        this.expenseAttachmentRepository = expenseAttachmentRepository;
        this.storageService = storageService;
        this.monthlyPeriodService = monthlyPeriodService;
        this.auditLogService = auditLogService;
    }

    @GetMapping
    public ResponseEntity<List<Expense>> getAllExpenses() {
        return ResponseEntity.ok(expenseRepository.findAllByOrderByExpenseDateDesc());
    }

    @GetMapping("/total-aprovado")
    public ResponseEntity<Double> getApprovedExpensesTotal() {
        return ResponseEntity.ok(expenseRepository.sumApprovedExpenses());
    }

    @GetMapping("/total-paga")
    public ResponseEntity<Double> getPaidExpensesTotal() {
        return ResponseEntity.ok(expenseRepository.sumPaidExpenses());
    }

    @GetMapping("/total-pendente")
    public ResponseEntity<Double> getPendingExpensesTotal() {
        return ResponseEntity.ok(expenseRepository.sumPendingExpenses());
    }

    @PostMapping
    public ResponseEntity<?> createExpense(@RequestBody ExpenseRequest request, Authentication authentication) {
        if (monthlyPeriodService.isPeriodLocked(request.getExpenseDate())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil deste mês está trancado para auditoria.");
        }
        Expense expense = new Expense();
        expense.setExpenseDate(request.getExpenseDate());
        expense.setDescription(request.getDescription());
        expense.setSupplier(request.getSupplier());
        expense.setCategory(request.getCategory());
        expense.setAmount(request.getAmount());
        expense.setPaymentMethod(request.getPaymentMethod());
        expense.setReceiptReference(request.getReceiptReference());
        expense.setObservations(request.getObservations());
        expense.setCreatedBy(authentication.getName());
        expense.setStatus("PENDING");

        Expense saved = expenseRepository.save(expense);
        return ResponseEntity.ok(saved);
    }

    @PutMapping("/{id}/approve")
    public ResponseEntity<?> approveExpense(@PathVariable Long id, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores ou tesoureiros podem aprovar despesas.");
        }

        return expenseRepository.findById(id).map(expense -> {
            if (monthlyPeriodService.isPeriodLocked(expense.getExpenseDate())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil deste mês está trancado para auditoria.");
            }
            if (!"PENDING".equals(expense.getStatus())) {
                return ResponseEntity.badRequest().body("Apenas despesas PENDENTES podem ser aprovadas.");
            }
            expense.setStatus("APPROVED");
            expense.setApprovedBy(authentication.getName());
            expense.setApprovalDate(LocalDate.now());
            Expense saved = expenseRepository.save(expense);
            auditLogService.logAction("EXPENSE_APPROVED", authentication.getName(), String.valueOf(saved.getId()), String.format("Aprovado: CHF %s - %s", saved.getAmount(), saved.getDescription()));
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/pay")
    public ResponseEntity<?> payExpense(@PathVariable Long id, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores ou tesoureiros podem pagar despesas.");
        }

        return expenseRepository.findById(id).map(expense -> {
            if (monthlyPeriodService.isPeriodLocked(expense.getExpenseDate())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil deste mês está trancado para auditoria.");
            }
            if (!"APPROVED".equals(expense.getStatus())) {
                return ResponseEntity.badRequest().body("Apenas despesas APROVADAS podem ser pagas. Uma despesa PENDENTE deve ser aprovada antes de ser liquidada.");
            }
            // Check if there is an active attachment (receipt) before paying
            boolean hasReceipt = expense.getAttachments().stream().anyMatch(ExpenseAttachment::isActive);
            if (!hasReceipt) {
                return ResponseEntity.badRequest().body("É obrigatório anexar um comprovante antes de registrar o pagamento.");
            }
            expense.setStatus("PAID");
            expense.setApprovedBy(authentication.getName());
            expense.setApprovalDate(LocalDate.now());
            Expense saved = expenseRepository.save(expense);
            auditLogService.logAction("EXPENSE_PAID", authentication.getName(), String.valueOf(saved.getId()), String.format("Paga: CHF %s - %s", saved.getAmount(), saved.getDescription()));
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/reject")
    public ResponseEntity<?> rejectExpense(@PathVariable Long id, @RequestBody RejectionRequest request, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores ou tesoureiros podem rejeitar despesas.");
        }
        if (request.getJustification() == null || request.getJustification().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("Justificativa de rejeição é obrigatória.");
        }

        return expenseRepository.findById(id).map(expense -> {
            if (monthlyPeriodService.isPeriodLocked(expense.getExpenseDate())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil deste mês está trancado para auditoria.");
            }
            if (!"PENDING".equals(expense.getStatus())) {
                return ResponseEntity.badRequest().body("Apenas despesas PENDENTES podem ser rejeitadas.");
            }
            expense.setStatus("REJECTED");
            expense.setRejectionJustification(request.getJustification());
            expense.setRejectedBy(authentication.getName());
            expense.setRejectionDate(java.time.LocalDate.now());
            Expense saved = expenseRepository.save(expense);
            auditLogService.logAction("EXPENSE_REJECTED", authentication.getName(), String.valueOf(saved.getId()), String.format("Rejeitado: %s. Justificativa: %s", saved.getDescription(), request.getJustification()));
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/reverse")
    public ResponseEntity<?> reverseExpense(@PathVariable Long id, @RequestBody ReversalRequest request, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores ou tesoureiros podem estornar despesas.");
        }
        if (request.getJustification() == null || request.getJustification().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("Justificativa de estorno é obrigatória.");
        }

        return expenseRepository.findById(id).map(expense -> {
            if (monthlyPeriodService.isPeriodLocked(expense.getExpenseDate())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil deste mês está trancado para auditoria.");
            }
            if (!"APPROVED".equals(expense.getStatus()) && !"PAID".equals(expense.getStatus())) {
                return ResponseEntity.badRequest().body("Apenas despesas APROVADAS ou PAGAS podem ser estornadas.");
            }
            expense.setStatus("REVERSED");
            expense.setReversalJustification(request.getJustification());
            expense.setReversedBy(authentication.getName());
            expense.setReversalDate(java.time.LocalDate.now());
            Expense saved = expenseRepository.save(expense);
            auditLogService.logAction("EXPENSE_REVERSED", authentication.getName(), String.valueOf(saved.getId()), String.format("Estornado: %s. Justificativa: %s", saved.getDescription(), request.getJustification()));
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updateExpense(@PathVariable Long id, @RequestBody ExpenseRequest request, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores ou tesoureiros podem editar despesas.");
        }

        return expenseRepository.findById(id).map(expense -> {
            if (monthlyPeriodService.isPeriodLocked(expense.getExpenseDate())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil deste mês está trancado para auditoria.");
            }
            if (request.getExpenseDate() != null && monthlyPeriodService.isPeriodLocked(request.getExpenseDate())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil do novo mês está trancado para auditoria.");
            }
            if (!"PENDING".equals(expense.getStatus())) {
                return ResponseEntity.badRequest().body("Apenas despesas PENDENTES podem ser editadas.");
            }
            expense.setAmount(request.getAmount());
            expense.setDescription(request.getDescription());
            expense.setCategory(request.getCategory());
            expense.setReceiptReference(request.getReceiptReference());
            if (request.getPaymentMethod() != null) {
                expense.setPaymentMethod(request.getPaymentMethod());
            }
            if (request.getExpenseDate() != null) {
                expense.setExpenseDate(request.getExpenseDate());
            }
            Expense saved = expenseRepository.save(expense);
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteExpense(@PathVariable Long id, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores ou tesoureiros podem excluir despesas.");
        }

        return expenseRepository.findById(id).map(expense -> {
            if (monthlyPeriodService.isPeriodLocked(expense.getExpenseDate())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("O período contábil deste mês está trancado para auditoria.");
            }
            if (!"PENDING".equals(expense.getStatus())) {
                return ResponseEntity.badRequest().body("Apenas despesas PENDENTES podem ser excluídas.");
            }
            expenseRepository.delete(expense);
            return ResponseEntity.ok().build();
        }).orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{expenseId}/attachments")
    public ResponseEntity<?> uploadAttachment(
            @PathVariable Long expenseId,
            @RequestParam("file") MultipartFile file,
            @RequestParam("documentType") DocumentType documentType,
            Authentication authentication) {

        return expenseRepository.findById(expenseId).map(expense -> {
            if ("REJECTED".equals(expense.getStatus()) || "REVERSED".equals(expense.getStatus())) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body("Não é permitido adicionar anexos a despesas rejeitadas ou estornadas.");
            }

            if (file.isEmpty()) {
                return ResponseEntity.badRequest().body("Arquivo vazio.");
            }
            if (file.getSize() > 5 * 1024 * 1024) {
                return ResponseEntity.badRequest().body("Tamanho máximo de arquivo permitido é 5MB.");
            }

            String contentType = file.getContentType();
            String originalFilename = file.getOriginalFilename();
            String ext = getFileExtension(originalFilename);

            if (!isValidFormat(contentType, ext)) {
                return ResponseEntity.badRequest().body("Formato de arquivo não suportado. Apenas PDF, JPG, JPEG e PNG.");
            }

            String uuid = UUID.randomUUID().toString();
            String storagePath = "expenses/" + expenseId + "/" + uuid + "." + ext;

            try {
                storageService.save(storagePath, file);

                ExpenseAttachment attachment = new ExpenseAttachment();
                attachment.setExpense(expense);
                attachment.setDocumentType(documentType);
                attachment.setFileName(originalFilename);
                attachment.setContentType(contentType);
                attachment.setStoragePath(storagePath);
                attachment.setFileSize(file.getSize());
                attachment.setUploadedBy(authentication.getName());
                attachment.setUploadedAt(LocalDateTime.now());
                attachment.setActive(true);

                ExpenseAttachment saved = expenseAttachmentRepository.save(attachment);
                
                expense.getAttachments().add(saved);
                expenseRepository.save(expense);

                return ResponseEntity.status(HttpStatus.CREATED).body(saved);
            } catch (Exception e) {
                return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                        .body("Erro ao salvar arquivo: " + e.getMessage());
            }
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{expenseId}/attachments/{attachmentId}/deactivate")
    public ResponseEntity<?> deactivateAttachment(
            @PathVariable Long expenseId,
            @PathVariable Long attachmentId,
            @RequestBody DeactivationRequest request,
            Authentication authentication) {

        if (request.getJustification() == null || request.getJustification().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("Justificativa de desativação é obrigatória.");
        }

        Optional<Expense> expenseOpt = expenseRepository.findById(expenseId);
        if (expenseOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        Expense expense = expenseOpt.get();

        if (!"PENDING".equals(expense.getStatus())) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body("Apenas despesas PENDENTES podem ter anexos desativados.");
        }

        Optional<ExpenseAttachment> attachmentOpt = expenseAttachmentRepository.findByIdAndExpenseId(attachmentId, expenseId);
        if (attachmentOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body("Anexo não encontrado ou não pertence a esta despesa.");
        }

        ExpenseAttachment attachment = attachmentOpt.get();
        attachment.setActive(false);
        attachment.setDeactivatedBy(authentication.getName());
        attachment.setDeactivatedAt(LocalDateTime.now());
        attachment.setDeactivationJustification(request.getJustification());

        ExpenseAttachment saved = expenseAttachmentRepository.save(attachment);
        return ResponseEntity.ok(saved);
    }

    @GetMapping("/{expenseId}/attachments/{attachmentId}")
    public ResponseEntity<?> downloadAttachment(
            @PathVariable Long expenseId,
            @PathVariable Long attachmentId) {

        Optional<ExpenseAttachment> attachmentOpt = expenseAttachmentRepository.findByIdAndExpenseId(attachmentId, expenseId);
        if (attachmentOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                    .body("Anexo não encontrado ou não pertence a esta despesa.");
        }

        ExpenseAttachment attachment = attachmentOpt.get();
        if (!attachment.isActive()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Este anexo foi desativado.");
        }

        try {
            byte[] data = storageService.load(attachment.getStoragePath());
            return ResponseEntity.ok()
                    .header("Content-Type", attachment.getContentType())
                    .header("Content-Disposition", "inline; filename=\"" + attachment.getFileName() + "\"")
                    .body(data);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Erro ao ler arquivo: " + e.getMessage());
        }
    }

    private String getFileExtension(String filename) {
        if (filename == null || !filename.contains(".")) return "";
        return filename.substring(filename.lastIndexOf(".") + 1).toLowerCase();
    }

    private boolean isValidFormat(String contentType, String ext) {
        boolean validMime = "application/pdf".equals(contentType)
                || "image/jpeg".equals(contentType)
                || "image/png".equals(contentType);
        boolean validExt = "pdf".equals(ext) || "jpg".equals(ext) || "jpeg".equals(ext) || "png".equals(ext);
        return validMime && validExt;
    }

    private boolean isAuthorizedToManage(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_TREASURER"));
    }
}

@Data
class ExpenseRequest {
    private LocalDate expenseDate;
    private String description;
    private String supplier;
    private String category;
    private BigDecimal amount;
    private String paymentMethod;
    private String receiptReference;
    private String observations;
}

@Data
class ReversalRequest {
    private String justification;
}

@Data
class RejectionRequest {
    private String justification;
}

@Data
class DeactivationRequest {
    private String justification;
}
