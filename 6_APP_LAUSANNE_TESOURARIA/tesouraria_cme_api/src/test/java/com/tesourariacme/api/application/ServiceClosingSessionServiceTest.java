package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.ServiceClosingSession;
import com.tesourariacme.api.domain.ServiceClosingSessionStatus;
import com.tesourariacme.api.infrastructure.ServiceClosingSessionRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.application.AuditLogService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.dao.DataIntegrityViolationException;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.util.Optional;
import com.tesourariacme.api.domain.ServiceSchedule;
import com.tesourariacme.api.infrastructure.ServiceScheduleRepository;
import java.time.DayOfWeek;
import java.util.List;
import java.util.Arrays;
import java.util.Collections;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class ServiceClosingSessionServiceTest {

    private ServiceClosingSessionRepository repository;
    private ServiceScheduleRepository scheduleRepository;
    private ServiceClosingRepository closingRepository;
    private AuditLogService auditLogService;
    private ServiceClosingSessionService service;

    @BeforeEach
    public void setUp() {
        repository = mock(ServiceClosingSessionRepository.class);
        scheduleRepository = mock(ServiceScheduleRepository.class);
        closingRepository = mock(ServiceClosingRepository.class);
        auditLogService = mock(AuditLogService.class);
        service = new ServiceClosingSessionService(repository, scheduleRepository, closingRepository, auditLogService);
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

    @Test
    public void testFindScheduleForTime_FoundInScheduledTime() {
        LocalDateTime dt = LocalDateTime.of(2026, 8, 23, 10, 15); // Sunday 10:15
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(10, 0), LocalTime.of(12, 0), "Regular", true);
        
        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Arrays.asList(schedule));

        Optional<ServiceSchedule> matched = service.findScheduleForTime(dt);
        assertTrue(matched.isPresent());
        assertEquals("Regular", matched.get().getServiceType());
    }

    @Test
    public void testResolveOrCreateSession_CreatesNewSession() {
        LocalDateTime dt = LocalDateTime.of(2026, 8, 23, 10, 15); // Sunday 10:15
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(10, 0), LocalTime.of(12, 0), "Regular", true);
        schedule.setId(42L);

        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Arrays.asList(schedule));
        when(repository.findByServiceScheduleAndServiceDate(schedule, dt.toLocalDate()))
                .thenReturn(Optional.empty());
        when(repository.findByServiceDateAndServiceTime(dt.toLocalDate(), schedule.getStartTime()))
                .thenReturn(Optional.empty());
        when(repository.saveAndFlush(any(ServiceClosingSession.class)))
                .thenAnswer(inv -> inv.getArgument(0));

        ServiceClosingSession session = service.resolveOrCreateSession(dt, "Admilson");

        assertNotNull(session);
        assertEquals(schedule, session.getServiceSchedule());
        assertEquals(dt.toLocalDate(), session.getServiceDate());
        assertEquals(LocalTime.of(10, 0), session.getServiceTime());
        assertEquals(ServiceClosingSessionStatus.ACTIVE, session.getStatus());
        assertEquals("Admilson", session.getStartedBy());
    }

    @Test
    public void testResolveOrCreateSession_SecondCallIdempotentReturnsSameSession() {
        LocalDateTime dt = LocalDateTime.of(2026, 8, 23, 10, 15);
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(10, 0), LocalTime.of(12, 0), "Regular", true);
        schedule.setId(42L);

        ServiceClosingSession existing = new ServiceClosingSession();
        existing.setServiceSchedule(schedule);
        existing.setServiceDate(dt.toLocalDate());
        existing.setStatus(ServiceClosingSessionStatus.ACTIVE);
        existing.setExpiresAt(LocalDateTime.now().plusHours(1));

        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Arrays.asList(schedule));
        when(repository.findByServiceScheduleAndServiceDate(schedule, dt.toLocalDate()))
                .thenReturn(Optional.of(existing));

        ServiceClosingSession session = service.resolveOrCreateSession(dt, "Admilson");

        assertSame(existing, session);
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    public void testFindScheduleForTime_WithinPostTimeWindowAllowed() {
        LocalDateTime dt = LocalDateTime.of(2026, 8, 23, 12, 30); // Sunday 12:30 (endTime is 12:00, within +60 mins)
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(10, 0), LocalTime.of(12, 0), "Regular", true);

        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Arrays.asList(schedule));

        Optional<ServiceSchedule> matched = service.findScheduleForTime(dt);
        assertTrue(matched.isPresent());
    }

    @Test
    public void testResolveOrCreateSession_NoWorshipApplicableThrowsException() {
        LocalDateTime dt = LocalDateTime.of(2026, 8, 23, 16, 00); // Sunday 16:00 (outside any window)
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(10, 0), LocalTime.of(12, 0), "Regular", true);

        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Arrays.asList(schedule));

        assertThrows(IllegalArgumentException.class, () -> {
            service.resolveOrCreateSession(dt, "Admilson");
        });
    }

    @Test
    public void testResolveOrCreateSession_InactiveScheduleIsIgnored() {
        LocalDateTime dt = LocalDateTime.of(2026, 8, 23, 10, 15);
        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Collections.emptyList()); // Active schedules list is empty

        assertThrows(IllegalArgumentException.class, () -> {
            service.resolveOrCreateSession(dt, "Admilson");
        });
    }

    @Test
    public void testFindScheduleForTime_TwoServicesSameDayDoNotCollide() {
        ServiceSchedule morning = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(10, 0), LocalTime.of(12, 0), "Morning", true);
        ServiceSchedule evening = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(19, 0), LocalTime.of(21, 0), "Evening", true);

        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Arrays.asList(morning, evening));

        // Test at 10:15
        Optional<ServiceSchedule> matchMorning = service.findScheduleForTime(LocalDateTime.of(2026, 8, 23, 10, 15));
        assertTrue(matchMorning.isPresent());
        assertEquals("Morning", matchMorning.get().getServiceType());

        // Test at 19:30
        Optional<ServiceSchedule> matchEvening = service.findScheduleForTime(LocalDateTime.of(2026, 8, 23, 19, 30));
        assertTrue(matchEvening.isPresent());
        assertEquals("Evening", matchEvening.get().getServiceType());
    }

    @Test
    public void testResolveOrCreateSession_LegacySessionSupport() {
        LocalDateTime dt = LocalDateTime.of(2026, 8, 23, 10, 15);
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SUNDAY, LocalTime.of(10, 0), LocalTime.of(12, 0), "Regular", true);
        schedule.setId(100L);

        ServiceClosingSession legacy = new ServiceClosingSession();
        legacy.setServiceDate(dt.toLocalDate());
        legacy.setServiceTime(schedule.getStartTime());
        legacy.setStatus(ServiceClosingSessionStatus.ACTIVE);
        legacy.setExpiresAt(LocalDateTime.now().plusHours(1));

        when(scheduleRepository.findByDayOfWeekAndActiveTrue(DayOfWeek.SUNDAY))
                .thenReturn(Arrays.asList(schedule));
        when(repository.findByServiceScheduleAndServiceDate(schedule, dt.toLocalDate()))
                .thenReturn(Optional.empty());
        when(repository.findByServiceDateAndServiceTime(dt.toLocalDate(), schedule.getStartTime()))
                .thenReturn(Optional.of(legacy));

        ServiceClosingSession resolved = service.resolveOrCreateSession(dt, "Admilson");

        assertSame(legacy, resolved);
        assertEquals(schedule, resolved.getServiceSchedule());
        verify(repository, times(1)).saveAndFlush(legacy);
    }

    @Test
    public void testCreateOrResumeLateSession_ResumesActive() {
        LocalDate date = LocalDate.of(2026, 8, 22);
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SATURDAY, LocalTime.of(19, 30), LocalTime.of(21, 0), "Regular", true);
        schedule.setId(10L);

        ServiceClosingSession existing = new ServiceClosingSession();
        existing.setId(200L);
        existing.setStatus(ServiceClosingSessionStatus.ACTIVE);

        when(scheduleRepository.findById(10L)).thenReturn(Optional.of(schedule));
        when(repository.findByServiceScheduleAndServiceDate(schedule, date)).thenReturn(Optional.of(existing));

        ServiceClosingSession result = service.createOrResumeLateSession(10L, date, "Admilson");
        assertSame(existing, result);
    }

    @Test
    public void testCreateOrResumeLateSession_ThrowsIfFinished() {
        LocalDate date = LocalDate.of(2026, 8, 22);
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SATURDAY, LocalTime.of(19, 30), LocalTime.of(21, 0), "Regular", true);
        schedule.setId(10L);

        ServiceClosingSession existing = new ServiceClosingSession();
        existing.setStatus(ServiceClosingSessionStatus.FINISHED);

        when(scheduleRepository.findById(10L)).thenReturn(Optional.of(schedule));
        when(repository.findByServiceScheduleAndServiceDate(schedule, date)).thenReturn(Optional.of(existing));

        assertThrows(IllegalArgumentException.class, () -> {
            service.createOrResumeLateSession(10L, date, "Admilson");
        });
    }

    @Test
    public void testCreateOrResumeLateSession_ThrowsIfClosingExists() {
        LocalDate date = LocalDate.of(2026, 8, 22);
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SATURDAY, LocalTime.of(19, 30), LocalTime.of(21, 0), "Regular", true);
        schedule.setId(10L);

        com.tesourariacme.api.domain.ServiceClosing closing = new com.tesourariacme.api.domain.ServiceClosing();
        closing.setServiceDate(date);

        when(scheduleRepository.findById(10L)).thenReturn(Optional.of(schedule));
        when(closingRepository.findByServiceDateBetween(date, date)).thenReturn(Arrays.asList(closing));

        assertThrows(IllegalArgumentException.class, () -> {
            service.createOrResumeLateSession(10L, date, "Admilson");
        });
    }

    @Test
    public void testCreateOrResumeLateSession_CreatesNewWithLateOpeningTrue() {
        LocalDate date = LocalDate.of(2026, 8, 22);
        ServiceSchedule schedule = new ServiceSchedule(DayOfWeek.SATURDAY, LocalTime.of(19, 30), LocalTime.of(21, 0), "Regular", true);
        schedule.setId(10L);

        when(scheduleRepository.findById(10L)).thenReturn(Optional.of(schedule));
        when(repository.findByServiceScheduleAndServiceDate(schedule, date)).thenReturn(Optional.empty());
        when(repository.findByServiceDateAndServiceTime(date, schedule.getStartTime())).thenReturn(Optional.empty());
        when(repository.saveAndFlush(any(ServiceClosingSession.class))).thenAnswer(inv -> inv.getArgument(0));

        ServiceClosingSession result = service.createOrResumeLateSession(10L, date, "Admilson");

        assertNotNull(result);
        assertTrue(result.isLateOpening());
        assertEquals("Admilson", result.getStartedBy());
        assertEquals(ServiceClosingSessionStatus.ACTIVE, result.getStatus());
        verify(auditLogService, times(1)).logAction(eq("LATE_OPENING"), eq("Admilson"), anyString(), anyString());
    }
}
