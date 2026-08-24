package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.presentation.MovementDTO;
import com.tesourariacme.api.presentation.MovementResponseDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

@Service
@RequiredArgsConstructor
public class MovementService {

    private final ExpenseRepository expenseRepository;
    private final ServiceClosingRepository serviceClosingRepository;

    public MovementResponseDTO getMovementsByMonth(int year, int month) {
        YearMonth yearMonth = YearMonth.of(year, month);
        LocalDate startDate = yearMonth.atDay(1);
        LocalDate endDate = yearMonth.atEndOfMonth();

        List<ServiceClosing> closings = serviceClosingRepository.findByServiceDateBetween(startDate, endDate);
        List<Expense> expenses = expenseRepository.findByExpenseDateBetweenAndStatusIn(startDate, endDate, Arrays.asList("APPROVED", "PAID"));

        List<MovementDTO> items = new ArrayList<>();
        BigDecimal totalIncomes = BigDecimal.ZERO;
        BigDecimal totalOutcomes = BigDecimal.ZERO;

        for (ServiceClosing closing : closings) {
            BigDecimal total = closing.getPhysicalTotal();
            totalIncomes = totalIncomes.add(total);

            String treasurer = closing.getMainTreasurer() != null ? closing.getMainTreasurer() : "";
            String incomeDesc = treasurer.isEmpty()
                    ? "Fechamento do culto"
                    : "Fechamento do culto — " + treasurer;

            items.add(MovementDTO.builder()
                    .id(String.valueOf(closing.getId()))
                    .date(closing.getServiceDate())
                    .type("INCOME")
                    .category("Fechamento de Culto")
                    .description(incomeDesc)
                    .value(total)
                    .status("COMPLETED")
                    .build());
        }

        for (Expense expense : expenses) {
            BigDecimal val = expense.getAmount();
            totalOutcomes = totalOutcomes.add(val);

            items.add(MovementDTO.builder()
                    .id(String.valueOf(expense.getId()))
                    .date(expense.getExpenseDate())
                    .type("OUTCOME")
                    .category(expense.getCategory() != null ? expense.getCategory() : "Despesa")
                    .description(expense.getDescription())
                    .value(val)
                    .status(expense.getStatus())
                    .build());
        }

        items.sort(Comparator.comparing(MovementDTO::getDate).reversed());

        MovementResponseDTO response = new MovementResponseDTO();
        String monthStr = String.format("%02d", month);
        response.setReference(monthStr + "/" + year);
        response.setTotalIncomes(totalIncomes);
        response.setTotalOutcomes(totalOutcomes);
        response.setBalance(totalIncomes.subtract(totalOutcomes));
        response.setItems(items);

        return response;
    }
}
