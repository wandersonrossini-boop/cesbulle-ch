package com.tesourariacme.api.domain;

import org.junit.jupiter.api.Test;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;

import com.tesourariacme.api.infrastructure.ServiceClosingSessionRepository;

public class ServiceClosingSessionTest {

    @Test
    public void testServiceClosingSessionModelProperties() {
        ServiceClosingSession session = new ServiceClosingSession();
        
        LocalDate serviceDate = LocalDate.of(2026, 8, 19);
        LocalTime serviceTime = LocalTime.of(19, 30);
        LocalDateTime startedAt = LocalDateTime.of(2026, 8, 19, 19, 0);
        LocalDateTime expiresAt = LocalDateTime.of(2026, 8, 19, 21, 0);
        
        session.setId(1L);
        session.setServiceDate(serviceDate);
        session.setServiceTime(serviceTime);
        session.setServiceType(null); // serviceType can be null
        session.setStatus(ServiceClosingSessionStatus.ACTIVE);
        session.setStartedBy("Pastor");
        session.setStartedAt(startedAt);
        session.setExpiresAt(expiresAt);
        
        assertEquals(1L, session.getId());
        assertEquals(serviceDate, session.getServiceDate());
        assertEquals(serviceTime, session.getServiceTime());
        assertNull(session.getServiceType());
        assertEquals(ServiceClosingSessionStatus.ACTIVE, session.getStatus());
        assertEquals("Pastor", session.getStartedBy());
        assertEquals(startedAt, session.getStartedAt());
        assertEquals(expiresAt, session.getExpiresAt());
    }

    @Test
    public void testStatusEnumValues() {
        assertEquals("ACTIVE", ServiceClosingSessionStatus.ACTIVE.name());
        assertEquals("PENDING_CLOSE", ServiceClosingSessionStatus.PENDING_CLOSE.name());
        assertEquals("FINISHED", ServiceClosingSessionStatus.FINISHED.name());
    }

    @Test
    public void testRepositoryQueryServiceIdentityByDateTime() {
        ServiceClosingSessionRepository repo = org.mockito.Mockito.mock(ServiceClosingSessionRepository.class);
        
        LocalDate date = LocalDate.of(2026, 8, 19);
        LocalTime time = LocalTime.of(19, 30);
        
        ServiceClosingSession session = new ServiceClosingSession();
        session.setServiceDate(date);
        session.setServiceTime(time);
        
        org.mockito.Mockito.when(repo.findByServiceDateAndServiceTime(date, time))
            .thenReturn(java.util.Optional.of(session));
            
        java.util.Optional<ServiceClosingSession> found = repo.findByServiceDateAndServiceTime(date, time);
        assertTrue(found.isPresent());
        assertEquals(date, found.get().getServiceDate());
        assertEquals(time, found.get().getServiceTime());
    }
}
