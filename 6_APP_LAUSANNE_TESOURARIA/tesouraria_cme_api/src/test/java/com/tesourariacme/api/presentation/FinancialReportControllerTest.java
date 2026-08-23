package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.FinancialReportService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class FinancialReportControllerTest {

    private FinancialReportService service;
    private com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService;
    private com.tesourariacme.api.application.AuditLogService auditLogService;
    private FinancialReportController controller;
    private Authentication treasurerAuth;
    private Authentication readOnlyAuth;
    private Authentication adminAuth;

    @BeforeEach
    public void setUp() {
        service = mock(FinancialReportService.class);
        monthlyPeriodService = mock(com.tesourariacme.api.application.MonthlyPeriodService.class);
        auditLogService = mock(com.tesourariacme.api.application.AuditLogService.class);
        controller = new FinancialReportController(service, monthlyPeriodService, auditLogService);

        treasurerAuth = mock(Authentication.class);
        when(treasurerAuth.getName()).thenReturn("tesoureiro");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(treasurerAuth).getAuthorities();

        readOnlyAuth = mock(Authentication.class);
        when(readOnlyAuth.getName()).thenReturn("readOnly");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_USER"))).when(readOnlyAuth).getAuthorities();

        adminAuth = mock(Authentication.class);
        when(adminAuth.getName()).thenReturn("admin");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))).when(adminAuth).getAuthorities();
    }

    @Test
    public void testGetMonthlyReportAuthorized() {
        FinancialReportDTO dto = new FinancialReportDTO(
            new FinancialReportDTO.Period(8, 2026),
            new FinancialReportDTO.Summary(BigDecimal.TEN, BigDecimal.ONE, new BigDecimal("9.00")),
            List.of(), List.of(),
            new FinancialReportDTO.Metadata(LocalDateTime.now(), "CHF", "OFFICIAL")
        );
        when(service.generateMonthlyReport(8, 2026)).thenReturn(dto);

        ResponseEntity<?> response = controller.getMonthlyReport(8, 2026, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(dto, response.getBody());
    }

    @Test
    public void testGetMonthlyReportForbidden() {
        ResponseEntity<?> response = controller.getMonthlyReport(8, 2026, readOnlyAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }

    @Test
    public void testGetMonthlyReportCsvAuthorized() {
        when(service.generateMonthlyReportCsv(8, 2026)).thenReturn("CSV Content");
        ResponseEntity<?> response = controller.getMonthlyReportCsv(8, 2026, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("CSV Content", response.getBody());
    }

    @Test
    public void testGetMonthlyReportCsvForbidden() {
        ResponseEntity<?> response = controller.getMonthlyReportCsv(8, 2026, readOnlyAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }

    @Test
    public void testGetMonthlyStatus() {
        when(monthlyPeriodService.getPeriodStatus(2026, 8)).thenReturn("LOCKED");
        ResponseEntity<?> response = controller.getMonthlyStatus(8, 2026, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        java.util.Map<?, ?> body = (java.util.Map<?, ?>) response.getBody();
        assertEquals("LOCKED", body.get("status"));
    }

    @Test
    public void testLockUnlockAuthorized() {
        ResponseEntity<?> lockResp = controller.lockMonthlyPeriod(8, 2026, adminAuth);
        assertEquals(HttpStatus.OK, lockResp.getStatusCode());
        verify(monthlyPeriodService).lockPeriod(2026, 8, "admin");

        ResponseEntity<?> unlockResp = controller.unlockMonthlyPeriod(8, 2026, adminAuth);
        assertEquals(HttpStatus.OK, unlockResp.getStatusCode());
        verify(monthlyPeriodService).unlockPeriod(2026, 8);
    }

    @Test
    public void testLockUnlockForbiddenForTreasurer() {
        ResponseEntity<?> lockResp = controller.lockMonthlyPeriod(8, 2026, treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, lockResp.getStatusCode());

        ResponseEntity<?> unlockResp = controller.unlockMonthlyPeriod(8, 2026, treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, unlockResp.getStatusCode());
    }

    @Test
    public void testGetMonthlyReportPdfAuthorized() {
        byte[] mockPdf = new byte[]{1, 2, 3};
        when(service.generateMonthlyReportPdf(8, 2026)).thenReturn(mockPdf);

        ResponseEntity<?> response = controller.getMonthlyReportPdf(8, 2026, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertArrayEquals(mockPdf, (byte[]) response.getBody());
    }

    @Test
    public void testGetMonthlyReportPdfForbidden() {
        ResponseEntity<?> response = controller.getMonthlyReportPdf(8, 2026, readOnlyAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }
}
