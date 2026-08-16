package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.ExpenseAttachment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface ExpenseAttachmentRepository extends JpaRepository<ExpenseAttachment, Long> {
    Optional<ExpenseAttachment> findByIdAndExpenseId(Long id, Long expenseId);
}
