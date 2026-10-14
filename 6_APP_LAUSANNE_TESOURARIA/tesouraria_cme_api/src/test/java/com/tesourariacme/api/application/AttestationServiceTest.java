package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.Contributor;
import com.tesourariacme.api.domain.Envelope;
import com.tesourariacme.api.domain.EnvelopeType;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.infrastructure.ContributorRepository;
import com.tesourariacme.api.infrastructure.EnvelopeRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.presentation.AnnualSummaryDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class AttestationServiceTest {

    private ContributorRepository contributorRepository;
    private EnvelopeRepository envelopeRepository;
    private ServiceClosingRepository serviceClosingRepository;
    private AttestationService attestationService;

    @BeforeEach
    public void setUp() {
        contributorRepository = mock(ContributorRepository.class);
        envelopeRepository = mock(EnvelopeRepository.class);
        serviceClosingRepository = mock(ServiceClosingRepository.class);
        attestationService = new AttestationService(contributorRepository, envelopeRepository, serviceClosingRepository);
    }

    @Test
    public void testContributorNotFoundThrowsException() {
        when(contributorRepository.findById(99L)).thenReturn(Optional.empty());

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> attestationService.generateAnnualSummary(99L, 2026));
        assertTrue(ex.getMessage().contains("Contribuinte não encontrado"));
    }

    @Test
    public void testIncompleteAddressThrowsException() {
        Contributor c = new Contributor();
        c.setId(1L);
        c.setFullName("João Silva");
        c.setContributorNumber("LS-001");
        c.setAddress(""); // Empty address
        c.setPostalCode("1000");
        c.setCity("Lausanne");

        when(contributorRepository.findById(1L)).thenReturn(Optional.of(c));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class,
                () -> attestationService.generateAnnualSummary(1L, 2026));
        assertTrue(ex.getMessage().contains("Dados cadastrais incompletos"));
    }

    @Test
    public void testZeroContributionsThrowsException() {
        Contributor c = new Contributor();
        c.setId(1L);
        c.setFullName("João Silva");
        c.setContributorNumber("LS-001");
        c.setAddress("Rue de Genève 1");
        c.setPostalCode("1003");
        c.setCity("Lausanne");

        when(contributorRepository.findById(1L)).thenReturn(Optional.of(c));
        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of());

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> attestationService.generateAnnualSummary(1L, 2026));
        assertTrue(ex.getMessage().contains("não possui contribuições registradas"));
    }

    @Test
    public void testValidContributionsWithIdGeneratesSummaryAndPdf() {
        Contributor c = new Contributor();
        c.setId(1L);
        c.setFullName("João Silva");
        c.setContributorNumber("LS-001");
        c.setAddress("Rue de Genève 1");
        c.setPostalCode("1003");
        c.setCity("Lausanne");

        ServiceClosing sc = new ServiceClosing();
        sc.setServiceDate(LocalDate.of(2026, 3, 15));

        Envelope env1 = new Envelope();
        env1.setContributorId(1L);
        env1.setMemberName("João Silva");
        env1.setType(EnvelopeType.DIZIMO);
        env1.setAmount(new BigDecimal("150.00"));

        Envelope env2 = new Envelope();
        env2.setContributorId(1L);
        env2.setMemberName("João Silva");
        env2.setType(EnvelopeType.VOTO);
        env2.setAmount(new BigDecimal("50.00"));

        sc.setIdentifiedEntries(List.of(env1, env2));

        when(contributorRepository.findById(1L)).thenReturn(Optional.of(c));
        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(sc));

        AnnualSummaryDTO summary = attestationService.generateAnnualSummary(1L, 2026);
        assertNotNull(summary);
        assertEquals(new BigDecimal("150.00"), summary.getTotalTithes());
        assertEquals(new BigDecimal("50.00"), summary.getTotalVows());
        assertEquals(new BigDecimal("200.00"), summary.getTotalConsolidated());
        assertEquals(2, summary.getDetails().size());

        byte[] pdfBytes = attestationService.generateAttestationPdf(1L, 2026);
        assertNotNull(pdfBytes);
        assertTrue(pdfBytes.length > 500); // Valid PDF header and content
    }

    @Test
    public void testFallbackMatchingByMemberNameWhenContributorIdNull() {
        Contributor c = new Contributor();
        c.setId(2L);
        c.setFullName("Maria Santos");
        c.setContributorNumber("LS-002");
        c.setAddress("Avenue de la Gare 5");
        c.setPostalCode("1003");
        c.setCity("Lausanne");

        ServiceClosing sc = new ServiceClosing();
        sc.setServiceDate(LocalDate.of(2026, 4, 10));

        Envelope env = new Envelope();
        env.setContributorId(null); // legacy closing record
        env.setMemberName("Maria Santos");
        env.setType(EnvelopeType.DIZIMO);
        env.setAmount(new BigDecimal("300.00"));

        sc.setIdentifiedEntries(List.of(env));

        when(contributorRepository.findById(2L)).thenReturn(Optional.of(c));
        when(serviceClosingRepository.findByServiceDateBetween(any(LocalDate.class), any(LocalDate.class)))
                .thenReturn(List.of(sc));

        AnnualSummaryDTO summary = attestationService.generateAnnualSummary(2L, 2026);
        assertNotNull(summary);
        assertEquals(new BigDecimal("300.00"), summary.getTotalConsolidated());
    }
}
