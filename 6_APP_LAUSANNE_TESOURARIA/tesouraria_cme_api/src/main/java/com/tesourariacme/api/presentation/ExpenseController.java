package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import lombok.Data;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/despesas")
public class ExpenseController {

    private final ExpenseRepository expenseRepository;

    public ExpenseController(ExpenseRepository expenseRepository) {
        this.expenseRepository = expenseRepository;
    }

    @GetMapping
    public ResponseEntity<List<Expense>> getAllExpenses() {
        return ResponseEntity.ok(expenseRepository.findAllByOrderByExpenseDateDesc());
    }

    @PostMapping
    public ResponseEntity<Expense> createExpense(@RequestBody ExpenseRequest request, Authentication authentication) {
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
        if (!isAdmin(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores podem aprovar despesas.");
        }

        return expenseRepository.findById(id).map(expense -> {
            expense.setStatus("APPROVED");
            expense.setApprovedBy(authentication.getName());
            expense.setApprovalDate(LocalDate.now());
            Expense saved = expenseRepository.save(expense);
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/reject")
    public ResponseEntity<?> rejectExpense(@PathVariable Long id, Authentication authentication) {
        if (!isAdmin(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores podem rejeitar despesas.");
        }

        return expenseRepository.findById(id).map(expense -> {
            expense.setStatus("REJECTED");
            Expense saved = expenseRepository.save(expense);
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    @PutMapping("/{id}/reverse")
    public ResponseEntity<?> reverseExpense(@PathVariable Long id, @RequestBody ReversalRequest request) {
        if (request.getJustification() == null || request.getJustification().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("Justificativa de estorno é obrigatória.");
        }

        return expenseRepository.findById(id).map(expense -> {
            expense.setStatus("REVERSED");
            expense.setReversalJustification(request.getJustification());
            Expense saved = expenseRepository.save(expense);
            return ResponseEntity.ok(saved);
        }).orElse(ResponseEntity.notFound().build());
    }

    private boolean isAdmin(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
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
class DeactivationRequest {
    private String justification;
}
