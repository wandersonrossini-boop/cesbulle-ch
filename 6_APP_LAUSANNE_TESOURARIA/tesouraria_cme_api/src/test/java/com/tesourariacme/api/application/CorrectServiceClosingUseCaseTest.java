package com.tesourariacme.api.application;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tesourariacme.api.domain.*;
import com.tesourariacme.api.infrastructure.AppUserRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingCorrectionRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.presentation.EnvelopeRequest;
import com.tesourariacme.api.presentation.ServiceClosingCorrectionRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.access.AccessDeniedException;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class CorrectServiceClosingUseCaseTest {

    private ServiceClosingRepository closingRepository;
    private ServiceClosingCorrectionRepository correctionRepository;
    private AppUserRepository userRepository;
    private MonthlyPeriodService monthlyPeriodService;
    private AuditLogService auditLogService;
    private ObjectMapper objectMapper;
    private CorrectServiceClosingUseCase useCase;

    @BeforeEach
    public void setUp() {
        closingRepository = mock(ServiceClosingRepository.class);
        correctionRepository = mock(ServiceClosingCorrectionRepository.class);
        userRepository = mock(AppUserRepository.class);
        monthlyPeriodService = mock(MonthlyPeriodService.class);
        auditLogService = mock(AuditLogService.class);
        objectMapper = new ObjectMapper();

        useCase = new CorrectServiceClosingUseCase(
                closingRepository,
                correctionRepository,
                userRepository,
                monthlyPeriodService,
                auditLogService,
                objectMapper
        );
    }

    @Test
    public void testCorrectionThrowsWhenReasonEmpty() {
        ServiceClosingCorrectionRequest req = new ServiceClosingCorrectionRequest();
        req.setReason("   ");

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> {
            useCase.execute(1L, req, "admin");
        });
        assertTrue(ex.getMessage().contains("justificativa"));
    }

    @Test
    public void testCorrectionThrowsWhenUserUnauthorized() {
        ServiceClosingCorrectionRequest req = new ServiceClosingCorrectionRequest();
        req.setReason("Ajuste de teste");

        AppUser user = new AppUser();
        user.setUsername("membro_comum");
        user.setRole("MEMBRO");
        user.setAuthorized(false);

        when(userRepository.findByUsername("membro_comum")).thenReturn(Optional.of(user));

        assertThrows(AccessDeniedException.class, () -> {
            useCase.execute(1L, req, "membro_comum");
        });
    }

    @Test
    public void testCorrectionThrowsWhenUserHasNoAdminOrTreasurerRole() {
        ServiceClosingCorrectionRequest req = new ServiceClosingCorrectionRequest();
        req.setReason("Ajuste de teste");

        AppUser user = new AppUser();
        user.setUsername("diacono");
        user.setRole("DIACONO");
        user.setAuthorized(true);

        when(userRepository.findByUsername("diacono")).thenReturn(Optional.of(user));

        AccessDeniedException ex = assertThrows(AccessDeniedException.class, () -> {
            useCase.execute(1L, req, "diacono");
        });
        assertTrue(ex.getMessage().contains("Apenas usuários autorizados"));
    }

    @Test
    public void testSuccessfulCorrectionPreservesAuditAndHistory() {
        AppUser admin = new AppUser();
        admin.setUsername("pastor");
        admin.setRole("ADMIN");
        admin.setAuthorized(true);
        when(userRepository.findByUsername("pastor")).thenReturn(Optional.of(admin));

        ServiceClosing closing = new ServiceClosing();
        closing.setId(10L);
        closing.setServiceDate(LocalDate.now());
        closing.setPhysicalTotal(new BigDecimal("100.00"));
        closing.setUnidentifiedOfertaTotal(new BigDecimal("100.00"));
        closing.setIdentifiedEntries(new ArrayList<>());
        closing.calculateTotalsAndValidate();

        when(closingRepository.findById(10L)).thenReturn(Optional.of(closing));
        when(closingRepository.save(any(ServiceClosing.class))).thenAnswer(i -> i.getArgument(0));
        when(correctionRepository.save(any(ServiceClosingCorrection.class))).thenAnswer(i -> {
            ServiceClosingCorrection c = i.getArgument(0);
            c.setId(1L);
            return c;
        });

        ServiceClosingCorrectionRequest req = new ServiceClosingCorrectionRequest();
        req.setReason("Oferta avulsa contada a mais por engano");
        req.setPhysicalTotal(new BigDecimal("80.00"));
        req.setUnidentifiedOfertaTotal(new BigDecimal("80.00"));

        ServiceClosingCorrection result = useCase.execute(10L, req, "pastor");

        assertNotNull(result);
        assertEquals(new BigDecimal("100.00"), result.getOriginalPhysicalTotal());
        assertEquals(new BigDecimal("80.00"), result.getCorrectedPhysicalTotal());
        assertEquals(new BigDecimal("-20.00"), result.getDifference());
        assertEquals("Oferta avulsa contada a mais por engano", result.getReason());
        assertEquals("pastor", result.getCorrectedBy());
        assertNotNull(result.getCreatedAt());

        verify(auditLogService).logAction(eq("CLOSING_CORRECTED"), eq("pastor"), eq("10"), anyString());
        verify(correctionRepository).save(any(ServiceClosingCorrection.class));
    }
}
