package com.tesourariacme.api.presentation;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class FinancialReportDTO {
    private Period period;
    private Summary summary;
    private List<CategorySummary> incomesByCategory;
    private List<CategorySummary> expensesByCategory;
    private Metadata metadata;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Period {
        private int month;
        private int year;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Summary {
        private BigDecimal totalIncomes;
        private BigDecimal totalExpenses;
        private BigDecimal netBalance;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class CategorySummary {
        private String category;
        private BigDecimal total;
        private long count;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Metadata {
        private LocalDateTime generatedAt;
        private String currency;
        private String status;
    }
}
