package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.ServiceClosingSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;

@Repository
public interface ServiceClosingSessionRepository extends JpaRepository<ServiceClosingSession, Long> {
    Optional<ServiceClosingSession> findByServiceDateAndServiceTime(LocalDate serviceDate, LocalTime serviceTime);
}
