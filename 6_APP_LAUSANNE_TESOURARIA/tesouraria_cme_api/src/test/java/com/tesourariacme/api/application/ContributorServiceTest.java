package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.Contributor;
import com.tesourariacme.api.infrastructure.ContributorRepository;
import com.tesourariacme.api.infrastructure.EnvelopeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

public class ContributorServiceTest {

    private ContributorRepository repository;
    private EnvelopeRepository envelopeRepository;
    private ContributorService service;

    @BeforeEach
    public void setUp() {
        repository = mock(ContributorRepository.class);
        envelopeRepository = mock(EnvelopeRepository.class);
        service = new ContributorService(repository, envelopeRepository);
    }

    @Test
    public void testCreateSuccessWithExplicitNumber() {
        Contributor c = new Contributor();
        c.setFullName("João Silva");
        c.setContributorNumber("1234");
        when(repository.findByContributorNumberIgnoreCase("1234")).thenReturn(Optional.empty());
        when(repository.save(c)).thenReturn(c);

        Contributor res = service.create(c);
        assertNotNull(res);
        assertEquals("1234", res.getContributorNumber());
        verify(repository, times(1)).save(c);
    }

    @Test
    public void testCreateAutoNumberingWhenEmpty() {
        Contributor c = new Contributor();
        c.setFullName("Maria Santos");
        c.setContributorNumber("");

        when(repository.findAll()).thenReturn(java.util.List.of());
        when(repository.findByContributorNumberIgnoreCase("LS-001")).thenReturn(Optional.empty());
        when(repository.save(any(Contributor.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Contributor res = service.create(c);
        assertNotNull(res);
        assertEquals("LS-001", res.getContributorNumber());
    }

    @Test
    public void testCreateAutoNumberingIncrementsFromMax() {
        Contributor existing1 = new Contributor();
        existing1.setContributorNumber("LS-005");
        Contributor existing2 = new Contributor();
        existing2.setContributorNumber("LS-002");

        when(repository.findAll()).thenReturn(java.util.List.of(existing1, existing2));
        when(repository.findByContributorNumberIgnoreCase("LS-006")).thenReturn(Optional.empty());
        when(repository.save(any(Contributor.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Contributor c = new Contributor();
        c.setFullName("Carlos Pereira");
        Contributor res = service.create(c);
        assertEquals("LS-006", res.getContributorNumber());
    }

    @Test
    public void testCreateAutoNumberingSkipsCollision() {
        Contributor existing = new Contributor();
        existing.setContributorNumber("LS-001");

        when(repository.findAll()).thenReturn(java.util.List.of(existing));
        // Suppose candidate LS-002 is already taken by a non-standard entry:
        when(repository.findByContributorNumberIgnoreCase("LS-002")).thenReturn(Optional.of(new Contributor()));
        when(repository.findByContributorNumberIgnoreCase("LS-003")).thenReturn(Optional.empty());
        when(repository.save(any(Contributor.class))).thenAnswer(invocation -> invocation.getArgument(0));

        Contributor c = new Contributor();
        c.setFullName("Lucas Mendes");
        Contributor res = service.create(c);
        assertEquals("LS-003", res.getContributorNumber());
    }

    @Test
    public void testCreateMissingFullNameThrows() {
        Contributor c = new Contributor();
        c.setFullName("   ");
        assertThrows(IllegalArgumentException.class, () -> service.create(c));
    }

    @Test
    public void testCreateDuplicateThrows() {
        Contributor c = new Contributor();
        c.setFullName("Ana Costa");
        c.setContributorNumber("1234");
        when(repository.findByContributorNumberIgnoreCase("1234")).thenReturn(Optional.of(new Contributor()));

        assertThrows(IllegalArgumentException.class, () -> service.create(c));
    }
}
