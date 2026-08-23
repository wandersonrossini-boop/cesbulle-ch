package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.RecurringExpense;
import com.tesourariacme.api.infrastructure.RecurringExpenseRepository;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/despesas/recorrentes")
public class RecurringExpenseController {

    private final RecurringExpenseRepository recurringExpenseRepository;

    public RecurringExpenseController(RecurringExpenseRepository recurringExpenseRepository) {
        this.recurringExpenseRepository = recurringExpenseRepository;
    }

    private boolean isAuthorizedToManage(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_TREASURER"));
    }

    @GetMapping
    public ResponseEntity<?> getAll(Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        return ResponseEntity.ok(recurringExpenseRepository.findAll());
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody RecurringExpense recurringExpense, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        recurringExpense.setCreatedBy(authentication.getName());
        return ResponseEntity.ok(recurringExpenseRepository.save(recurringExpense));
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody RecurringExpense updated, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        return recurringExpenseRepository.findById(id).map(existing -> {
            existing.setDescription(updated.getDescription());
            existing.setAmount(updated.getAmount());
            existing.setCategory(updated.getCategory());
            existing.setDueDayOfMonth(updated.getDueDayOfMonth());
            existing.setActive(updated.isActive());
            return ResponseEntity.ok(recurringExpenseRepository.save(existing));
        }).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        if (recurringExpenseRepository.existsById(id)) {
            recurringExpenseRepository.deleteById(id);
            return ResponseEntity.ok().build();
        }
        return ResponseEntity.notFound().build();
    }
}
