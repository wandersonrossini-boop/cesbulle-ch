package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.RecurringExpense;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface RecurringExpenseRepository extends JpaRepository<RecurringExpense, Long> {
    List<RecurringExpense> findAllByActiveTrue();
    List<RecurringExpense> findAllByActiveTrueAndDueDayOfMonth(Integer dueDayOfMonth);
}
