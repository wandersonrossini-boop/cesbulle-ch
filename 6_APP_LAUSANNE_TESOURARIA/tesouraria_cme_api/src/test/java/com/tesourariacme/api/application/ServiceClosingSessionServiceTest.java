package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.ServiceClosingSession;
import com.tesourariacme.api.domain.ServiceClosingSessionStatus;
import com.tesourariacme.api.infrastructure.ServiceClosingSessionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.dao.DataIntegrityViolationException;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class ServiceClosingSessionServiceTest {

    private ServiceClosingSessionRepository repository;
    private ServiceClosingSessionService service;

    @BeforeEach
    public void setUp() {
        repository = mock(ServiceClosingSessionRepository.class);
        service = new ServiceClosingSessionService(repository);
    }

    @Test
    public void testGetOrCreate_Inexistent_CreatesActive() {
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime startTime = LocalTime.of(19, 30);
        LocalTime endTime = LocalTime.of(21, 0);

        when(repository.findByServiceDateAndServiceTime(date, startTime)).thenReturn(Optional.empty());
        when(repository.saveAndFlush(any(ServiceClosingSession.class))).thenAnswer(inv -> inv.getArgument(0));

        ServiceClosingSession session = service.getOrCreate(date, startTime, endTime, "Regular", "Admilson");

        assertNotNull(session);
        assertEquals(date, session.getServiceDate());
        assertEquals(startTime, session.getServiceTime());
        assertEquals(endTime, session.getServiceEndTime());
        assertEquals(ServiceClosingSessionStatus.ACTIVE, session.getStatus());
        assertEquals("Admilson", session.getStartedBy());
        assertNotNull(session.getStartedAt());
        assertEquals(LocalDateTime.of(date, endTime).plusMinutes(60), session.getExpiresAt());
        verify(repository, times(1)).saveAndFlush(any(ServiceClosingSession.class));
    }

    @Test
    public void testGetOrCreate_SpecificWorshipExpirationPolicy() {
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime startTime = LocalTime.of(10, 0);
        LocalTime endTime = LocalTime.of(12, 0);

        when(repository.findByServiceDateAndServiceTime(date, startTime)).thenReturn(Optional.empty());
        when(repository.saveAndFlush(any(ServiceClosingSession.class))).thenAnswer(inv -> inv.getArgument(0));

        ServiceClosingSession session = service.getOrCreate(date, startTime, endTime, "Regular", "Admilson");

        // Culto 10:00-12:00 -> expira às 13:00 (endTime 12:00 + 60 min)
        LocalDateTime expectedExpiry = LocalDateTime.of(2026, 8, 19, 13, 0);
        assertEquals(expectedExpiry, session.getExpiresAt());
    }

    @Test
    public void testGetOrCreate_ActiveValid_ReturnsSame() {
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime startTime = LocalTime.of(19, 30);
        LocalTime endTime = LocalTime.of(21, 0);

        ServiceClosingSession existing = new ServiceClosingSession();
        existing.setStatus(ServiceClosingSessionStatus.ACTIVE);
        existing.setExpiresAt(LocalDateTime.now().plusHours(2));

        when(repository.findByServiceDateAndServiceTime(date, startTime)).thenReturn(Optional.of(existing));

        ServiceClosingSession session = service.getOrCreate(date, startTime, endTime, "Regular", "Admilson");

        assertSame(existing, session);
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    public void testGetOrCreate_ActiveExpired_TransitionsToPendingClose() {
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime startTime = LocalTime.of(19, 30);
        LocalTime endTime = LocalTime.of(21, 0);

        ServiceClosingSession existing = new ServiceClosingSession();
        existing.setStatus(ServiceClosingSessionStatus.ACTIVE);
        existing.setExpiresAt(LocalDateTime.now().minusMinutes(5)); // expired

        when(repository.findByServiceDateAndServiceTime(date, startTime)).thenReturn(Optional.of(existing));
        when(repository.saveAndFlush(any(ServiceClosingSession.class))).thenAnswer(inv -> inv.getArgument(0));

        ServiceClosingSession session = service.getOrCreate(date, startTime, endTime, "Regular", "Admilson");

        assertEquals(ServiceClosingSessionStatus.PENDING_CLOSE, session.getStatus());
        verify(repository, times(1)).saveAndFlush(existing);
    }

    @Test
    public void testGetOrCreate_PendingClose_ReturnsSame() {
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime startTime = LocalTime.of(19, 30);
        LocalTime endTime = LocalTime.of(21, 0);

        ServiceClosingSession existing = new ServiceClosingSession();
        existing.setStatus(ServiceClosingSessionStatus.PENDING_CLOSE);

        when(repository.findByServiceDateAndServiceTime(date, startTime)).thenReturn(Optional.of(existing));

        ServiceClosingSession session = service.getOrCreate(date, startTime, endTime, "Regular", "Admilson");

        assertSame(existing, session);
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    public void testGetOrCreate_Finished_ThrowsException() {
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime startTime = LocalTime.of(19, 30);
        LocalTime endTime = LocalTime.of(21, 0);

        ServiceClosingSession existing = new ServiceClosingSession();
        existing.setStatus(ServiceClosingSessionStatus.FINISHED);

        when(repository.findByServiceDateAndServiceTime(date, startTime)).thenReturn(Optional.of(existing));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> {
            service.getOrCreate(date, startTime, endTime, "Regular", "Admilson");
        });
        assertTrue(ex.getMessage().contains("fechamento concluído"));
    }

    @Test
    public void testGetOrCreate_RaceCondition_ReturnsWinningSession() {
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime startTime = LocalTime.of(19, 30);
        LocalTime endTime = LocalTime.of(21, 0);

        when(repository.findByServiceDateAndServiceTime(date, startTime))
                .thenReturn(Optional.empty()) // First check: empty
                .thenAnswer(inv -> {
                    // Second check (during catch): returns winner
                    ServiceClosingSession winner = new ServiceClosingSession();
                    winner.setServiceDate(date);
                    winner.setServiceTime(startTime);
                    winner.setStatus(ServiceClosingSessionStatus.ACTIVE);
                    winner.setExpiresAt(LocalDateTime.now().plusHours(2));
                    return Optional.of(winner);
                });

        when(repository.saveAndFlush(any(ServiceClosingSession.class)))
                .thenThrow(new DataIntegrityViolationException("Duplicate key unique constraint violated"));

        ServiceClosingSession session = service.getOrCreate(date, startTime, endTime, "Regular", "Admilson");

        assertNotNull(session);
        assertEquals(date, session.getServiceDate());
        assertEquals(startTime, session.getServiceTime());
        assertEquals(ServiceClosingSessionStatus.ACTIVE, session.getStatus());
        verify(repository, times(1)).saveAndFlush(any(ServiceClosingSession.class));
    }

    @Test
    public void testServiceDraftFlow() {
        Long sessionId = 1L;
        ServiceClosingSession session = new ServiceClosingSession();
        session.setId(sessionId);
        session.setStatus(ServiceClosingSessionStatus.ACTIVE);

        when(repository.findById(sessionId)).thenReturn(Optional.of(session));
        when(repository.saveAndFlush(any(ServiceClosingSession.class))).thenAnswer(inv -> inv.getArgument(0));

        // Save
        service.saveDraft(sessionId, "{\"data\": 1}");
        assertEquals("{\"data\": 1}", session.getDraftJson());

        // Get
        Optional<String> retrieved = service.getDraft(sessionId);
        assertTrue(retrieved.isPresent());
        assertEquals("{\"data\": 1}", retrieved.get());

        // Update
        service.saveDraft(sessionId, "{\"data\": 2}");
        assertEquals("{\"data\": 2}", session.getDraftJson());

        // Clear
        service.clearDraft(sessionId);
        assertNull(session.getDraftJson());
    }

    @Test
    public void testServiceDraftFinishedBlocksChanges() {
        Long sessionId = 1L;
        ServiceClosingSession session = new ServiceClosingSession();
        session.setId(sessionId);
        session.setStatus(ServiceClosingSessionStatus.FINISHED);

        when(repository.findById(sessionId)).thenReturn(Optional.of(session));

        assertThrows(IllegalStateException.class, () -> {
            service.saveDraft(sessionId, "{\"data\": 1}");
        });

        assertThrows(IllegalStateException.class, () -> {
            service.clearDraft(sessionId);
        });
    }
}
