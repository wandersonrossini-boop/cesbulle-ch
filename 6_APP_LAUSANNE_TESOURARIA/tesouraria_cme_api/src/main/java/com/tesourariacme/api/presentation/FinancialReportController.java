package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.FinancialReportService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/reports/financial")
public class FinancialReportController {

    private final FinancialReportService financialReportService;
    private final com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService;
    private final com.tesourariacme.api.application.AuditLogService auditLogService;

    public FinancialReportController(
            FinancialReportService financialReportService,
            com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService,
            com.tesourariacme.api.application.AuditLogService auditLogService) {
        this.financialReportService = financialReportService;
        this.monthlyPeriodService = monthlyPeriodService;
        this.auditLogService = auditLogService;
    }

    private boolean isAuthorizedToManage(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_TREASURER"));
    }

    private boolean isAuthorizedToLock(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }

    @GetMapping("/monthly")
    public ResponseEntity<?> getMonthlyReport(
            @RequestParam("month") int month,
            @RequestParam("year") int year,
            Authentication authentication) {

        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }

        try {
            FinancialReportDTO report = financialReportService.generateMonthlyReport(month, year);
            return ResponseEntity.ok(report);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/monthly/csv")
    public ResponseEntity<?> getMonthlyReportCsv(
            @RequestParam("month") int month,
            @RequestParam("year") int year,
            Authentication authentication) {

        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }

        try {
            String csv = financialReportService.generateMonthlyReportCsv(month, year);
            return ResponseEntity.ok()
                    .header("Content-Type", "text/csv; charset=UTF-8")
                    .header("Content-Disposition", String.format("attachment; filename=relatorio_%02d_%d.csv", month, year))
                    .body(csv);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/monthly/status")
    public ResponseEntity<?> getMonthlyStatus(
            @RequestParam("month") int month,
            @RequestParam("year") int year,
            Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        String status = monthlyPeriodService.getPeriodStatus(year, month);
        java.util.Map<String, String> response = new java.util.HashMap<>();
        response.put("status", status);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/monthly/lock")
    public ResponseEntity<?> lockMonthlyPeriod(
            @RequestParam("month") int month,
            @RequestParam("year") int year,
            Authentication authentication) {
        if (!isAuthorizedToLock(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores podem trancar períodos contábeis.");
        }
        monthlyPeriodService.lockPeriod(year, month, authentication.getName());
        auditLogService.logAction("PERIOD_LOCKED", authentication.getName(), String.format("%d-%02d", year, month), "Competência contábil trancada para auditoria.");
        return ResponseEntity.ok().build();
    }

    @PostMapping("/monthly/unlock")
    public ResponseEntity<?> unlockMonthlyPeriod(
            @RequestParam("month") int month,
            @RequestParam("year") int year,
            Authentication authentication) {
        if (!isAuthorizedToLock(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Apenas administradores podem reabrir períodos contábeis.");
        }
        monthlyPeriodService.unlockPeriod(year, month);
        auditLogService.logAction("PERIOD_UNLOCKED", authentication.getName(), String.format("%d-%02d", year, month), "Competência contábil reaberta.");
        return ResponseEntity.ok().build();
    }

    @GetMapping("/monthly/pdf")
    public ResponseEntity<?> getMonthlyReportPdf(
            @RequestParam("month") int month,
            @RequestParam("year") int year,
            Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        try {
            byte[] pdfBytes = financialReportService.generateMonthlyReportPdf(month, year);
            return ResponseEntity.ok()
                    .header("Content-Type", "application/pdf")
                    .header("Content-Disposition", String.format("attachment; filename=relatorio_%02d_%d.pdf", month, year))
                    .body(pdfBytes);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }
}
