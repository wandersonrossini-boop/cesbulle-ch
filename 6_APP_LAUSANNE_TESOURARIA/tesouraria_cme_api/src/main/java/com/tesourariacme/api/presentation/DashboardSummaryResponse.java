package com.tesourariacme.api.presentation;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DashboardSummaryResponse {
    private String periodLabel;
    private boolean periodLocked;
    private BigDecimal currentMonthInputs;
    private long pendingExpensesCount;
    private BigDecimal pendingExpensesTotal;
    private long currentMonthClosingsCount;
}
