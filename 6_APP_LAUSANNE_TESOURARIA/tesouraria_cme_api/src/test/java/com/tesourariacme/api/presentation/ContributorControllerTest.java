package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.ContributorService;
import com.tesourariacme.api.application.AttestationService;
import com.tesourariacme.api.domain.Contributor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class ContributorControllerTest {

    private ContributorService service;
    private AttestationService attestationService;
    private com.tesourariacme.api.application.AuditLogService auditLogService;
    private ContributorController controller;
    private Authentication treasurerAuth;
    private Authentication readOnlyAuth;

    @BeforeEach
    public void setUp() {
        service = mock(ContributorService.class);
        attestationService = mock(AttestationService.class);
        auditLogService = mock(com.tesourariacme.api.application.AuditLogService.class);
        controller = new ContributorController(service, attestationService, auditLogService);

        treasurerAuth = mock(Authentication.class);
        when(treasurerAuth.getName()).thenReturn("tesoureiro");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(treasurerAuth).getAuthorities();

        readOnlyAuth = mock(Authentication.class);
        when(readOnlyAuth.getName()).thenReturn("readOnly");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_USER"))).when(readOnlyAuth).getAuthorities();
    }

    @Test
    public void testGetAllAuthorized() {
        when(service.getAll(any())).thenReturn(List.of(new Contributor()));
        ResponseEntity<?> response = controller.getAll("teste", treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
    }

    @Test
    public void testGetAllForbidden() {
        ResponseEntity<?> response = controller.getAll("teste", readOnlyAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }

    @Test
    public void testCreateSuccess() {
        Contributor c = new Contributor();
        c.setFullName("Membro");
        when(service.create(any())).thenReturn(c);

        ResponseEntity<?> response = controller.create(c, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
    }

    @Test
    public void testGetAnnualSummarySuccess() {
        AnnualSummaryDTO dto = new AnnualSummaryDTO(
                1L, "Nome", "Num", "Rua", "1000", "City", 2026,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, List.of()
        );
        when(attestationService.generateAnnualSummary(1L, 2026)).thenReturn(dto);

        ResponseEntity<?> response = controller.getAnnualSummary(1L, 2026, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(dto, response.getBody());
    }

    @Test
    public void testGetAttestationPdfSuccess() {
        byte[] dummyPdf = new byte[]{1, 2, 3};
        when(attestationService.generateAttestationPdf(1L, 2026)).thenReturn(dummyPdf);

        ResponseEntity<?> response = controller.getAttestationPdf(1L, 2026, treasurerAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertArrayEquals(dummyPdf, (byte[]) response.getBody());
    }

    @Test
    public void testGetAttestationPdfForbidden() {
        ResponseEntity<?> response = controller.getAttestationPdf(1L, 2026, readOnlyAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }
}
