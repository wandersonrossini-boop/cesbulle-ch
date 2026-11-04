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
    private PaymentMethodSummary paymentMethods;
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
    public static class Summary {
        private BigDecimal totalIncomes;
        private BigDecimal totalExpenses;
        private BigDecimal totalCommitted; // APPROVED ainda não pago — informativo, não integra o saldo realizado
        private BigDecimal netBalance;

        public Summary(BigDecimal totalIncomes, BigDecimal totalExpenses, BigDecimal netBalance) {
            this.totalIncomes = totalIncomes;
            this.totalExpenses = totalExpenses;
            this.totalCommitted = java.math.BigDecimal.ZERO;
            this.netBalance = netBalance;
        }

        public Summary(BigDecimal totalIncomes, BigDecimal totalExpenses, BigDecimal totalCommitted, BigDecimal netBalance) {
            this.totalIncomes = totalIncomes;
            this.totalExpenses = totalExpenses;
            this.totalCommitted = totalCommitted;
            this.netBalance = netBalance;
        }
    }

    public FinancialReportDTO(Period period, Summary summary, List<CategorySummary> incomesByCategory, List<CategorySummary> expensesByCategory, Metadata metadata) {
        this.period = period;
        this.summary = summary;
        this.paymentMethods = new PaymentMethodSummary(BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO);
        this.incomesByCategory = incomesByCategory;
        this.expensesByCategory = expensesByCategory;
        this.metadata = metadata;
    }

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PaymentMethodSummary {
        private BigDecimal totalDinheiro;
        private BigDecimal totalTwint;
        private BigDecimal totalTransferencias;
        private BigDecimal totalEletronico;
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
