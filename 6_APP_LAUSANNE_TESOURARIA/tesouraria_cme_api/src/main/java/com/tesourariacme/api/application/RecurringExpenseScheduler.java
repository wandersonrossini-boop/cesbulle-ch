package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.RecurringExpense;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.RecurringExpenseRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
public class RecurringExpenseScheduler {

    private final RecurringExpenseRepository recurringExpenseRepository;
    private final ExpenseRepository expenseRepository;

    public RecurringExpenseScheduler(
            RecurringExpenseRepository recurringExpenseRepository,
            ExpenseRepository expenseRepository) {
        this.recurringExpenseRepository = recurringExpenseRepository;
        this.expenseRepository = expenseRepository;
    }

    @Scheduled(cron = "0 0 1 * * ?")
    @Transactional
    public void generateRecurringExpenses() {
        int today = LocalDate.now().getDayOfMonth();
        List<RecurringExpense> activeExpenses = recurringExpenseRepository.findAllByActiveTrueAndDueDayOfMonth(today);

        for (RecurringExpense rec : activeExpenses) {
            Expense expense = new Expense();
            expense.setExpenseDate(LocalDate.now());
            expense.setDescription(rec.getDescription());
            expense.setAmount(rec.getAmount());
            expense.setCategory(rec.getCategory());
            expense.setSupplier("Recorrência Mensal");
            expense.setPaymentMethod("Outro");
            expense.setCreatedBy("Sistema (Recorrência)");
            expense.setStatus("PENDING");
            expense.setReceiptReference("");
            expenseRepository.save(expense);
        }
    }
}
