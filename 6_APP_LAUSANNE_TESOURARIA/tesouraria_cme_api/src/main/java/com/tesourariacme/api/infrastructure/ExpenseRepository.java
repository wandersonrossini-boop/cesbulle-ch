package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.Expense;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.time.LocalDate;
import java.util.List;

public interface ExpenseRepository extends JpaRepository<Expense, Long> {
    List<Expense> findAllByOrderByExpenseDateDesc();

    @Query("SELECT COALESCE(SUM(e.amount), 0.0) FROM Expense e WHERE e.status = 'APPROVED'")
    Double sumApprovedExpenses();

    List<Expense> findByExpenseDateBetweenAndStatusIn(LocalDate startDate, LocalDate endDate, List<String> statuses);

    List<Expense> findByStatus(String status);
}
