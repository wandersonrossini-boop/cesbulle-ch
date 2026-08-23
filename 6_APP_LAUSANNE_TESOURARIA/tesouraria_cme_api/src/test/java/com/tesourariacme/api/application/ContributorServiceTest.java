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
    public void testCreateSuccess() {
        Contributor c = new Contributor();
        c.setContributorNumber("1234");
        when(repository.findByContributorNumber("1234")).thenReturn(Optional.empty());
        when(repository.save(c)).thenReturn(c);

        Contributor res = service.create(c);
        assertNotNull(res);
        verify(repository, times(1)).save(c);
    }

    @Test
    public void testCreateDuplicateThrows() {
        Contributor c = new Contributor();
        c.setContributorNumber("1234");
        when(repository.findByContributorNumber("1234")).thenReturn(Optional.of(new Contributor()));

        assertThrows(IllegalArgumentException.class, () -> service.create(c));
    }
}
