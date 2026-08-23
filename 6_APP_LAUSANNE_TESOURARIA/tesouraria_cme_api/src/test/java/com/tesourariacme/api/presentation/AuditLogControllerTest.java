package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.AuditLogService;
import com.tesourariacme.api.domain.AuditLog;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class AuditLogControllerTest {

    private AuditLogService service;
    private AuditLogController controller;
    private Authentication adminAuth;
    private Authentication treasurerAuth;

    @BeforeEach
    public void setUp() {
        service = mock(AuditLogService.class);
        controller = new AuditLogController(service);

        adminAuth = mock(Authentication.class);
        when(adminAuth.getName()).thenReturn("admin");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_ADMIN"))).when(adminAuth).getAuthorities();

        treasurerAuth = mock(Authentication.class);
        when(treasurerAuth.getName()).thenReturn("treasurer");
        doReturn(List.of(new SimpleGrantedAuthority("ROLE_TREASURER"))).when(treasurerAuth).getAuthorities();
    }

    @Test
    public void testGetLogsAuthorized() {
        Page<AuditLog> page = new PageImpl<>(List.of(
                new AuditLog(1L, "PERIOD_LOCKED", "admin", "2026-08", "Detail lock", LocalDateTime.now())
        ));
        when(service.getLogs(PageRequest.of(0, 20))).thenReturn(page);

        ResponseEntity<?> response = controller.getLogs(0, 20, adminAuth);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals(page, response.getBody());
    }

    @Test
    public void testGetLogsForbidden() {
        ResponseEntity<?> response = controller.getLogs(0, 20, treasurerAuth);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
    }
}
