package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.Expense;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.infrastructure.ExpenseRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.application.MonthlyPeriodService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

@RestController
@RequestMapping("/api/dashboard")
public class DashboardController {

    private final ServiceClosingRepository serviceClosingRepository;
    private final ExpenseRepository expenseRepository;
    private final MonthlyPeriodService monthlyPeriodService;

    public DashboardController(
            ServiceClosingRepository serviceClosingRepository,
            ExpenseRepository expenseRepository,
            MonthlyPeriodService monthlyPeriodService) {
        this.serviceClosingRepository = serviceClosingRepository;
        this.expenseRepository = expenseRepository;
        this.monthlyPeriodService = monthlyPeriodService;
    }

    private boolean isAuthorized(Authentication authentication) {
        if (authentication == null) return false;
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_TREASURER"));
    }

    @GetMapping("/summary")
    public ResponseEntity<?> getDashboardSummary(Authentication authentication) {
        if (!isAuthorized(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }

        LocalDate now = LocalDate.now(ZoneId.of("Europe/Zurich"));
        int month = now.getMonthValue();
        int year = now.getYear();

        LocalDate start = now.withDayOfMonth(1);
        LocalDate end = now.withDayOfMonth(now.lengthOfMonth());

        // 1. Lock status
        boolean locked = monthlyPeriodService.isPeriodLocked(year, month);

        // 2. inputs
        List<ServiceClosing> closings = serviceClosingRepository.findByServiceDateBetween(start, end);
        BigDecimal inputs = BigDecimal.ZERO;
        for (ServiceClosing c : closings) {
            BigDecimal diz = c.getTotalDizimos() != null ? c.getTotalDizimos() : BigDecimal.ZERO;
            BigDecimal ofe = c.getTotalOfertas() != null ? c.getTotalOfertas() : BigDecimal.ZERO;
            BigDecimal vot = c.getTotalVotos() != null ? c.getTotalVotos() : BigDecimal.ZERO;
            inputs = inputs.add(diz).add(ofe).add(vot);
        }

        // 3. Pending expenses
        List<Expense> pending = expenseRepository.findByStatus("PENDING");
        long pendingCount = pending.size();
        BigDecimal pendingTotal = pending.stream()
                .map(e -> e.getAmount() != null ? e.getAmount() : BigDecimal.ZERO)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        String periodLabel = String.format("%02d/%d", month, year);

        DashboardSummaryResponse summary = new DashboardSummaryResponse(
                periodLabel,
                locked,
                inputs,
                pendingCount,
                pendingTotal,
                (long) closings.size()
        );

        return ResponseEntity.ok(summary);
    }
}
