package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.FinancialReportService;
import com.tesourariacme.api.application.GoogleSheetsService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/relatorios")
public class GoogleSheetsReportController {

    private final FinancialReportService financialReportService;
    private final GoogleSheetsService googleSheetsService;

    public GoogleSheetsReportController(FinancialReportService financialReportService, GoogleSheetsService googleSheetsService) {
        this.financialReportService = financialReportService;
        this.googleSheetsService = googleSheetsService;
    }

    private boolean isAuthorizedToManage(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_TREASURER"));
    }

    @PostMapping("/google-sheets")
    public ResponseEntity<?> createGoogleSheetsReport(
            @RequestParam("month") int month,
            @RequestParam("year") int year,
            Authentication authentication) {

        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }

        try {
            FinancialReportDTO report = financialReportService.generateMonthlyReport(month, year);
            GoogleSheetsResponseDTO response = googleSheetsService.createFinancialReportSheet(report, month, year);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
        }
    }
}
