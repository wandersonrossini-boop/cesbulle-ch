package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.ServiceClosingSession;
import com.tesourariacme.api.domain.ServiceClosingSessionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.tesourariacme.api.domain.ServiceSchedule;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface ServiceClosingSessionRepository extends JpaRepository<ServiceClosingSession, Long> {
    Optional<ServiceClosingSession> findByServiceDateAndServiceTime(LocalDate serviceDate, LocalTime serviceTime);
    Optional<ServiceClosingSession> findByServiceScheduleAndServiceDate(ServiceSchedule serviceSchedule, LocalDate serviceDate);
    boolean existsByServiceScheduleAndServiceDate(ServiceSchedule serviceSchedule, LocalDate serviceDate);
    List<ServiceClosingSession> findByServiceDateBetween(LocalDate startDate, LocalDate endDate);
    List<ServiceClosingSession> findByServiceScheduleAndServiceDateBetween(ServiceSchedule serviceSchedule, LocalDate startDate, LocalDate endDate);
}
