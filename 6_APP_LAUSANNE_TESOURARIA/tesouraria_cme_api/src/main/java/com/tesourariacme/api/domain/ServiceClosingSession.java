package com.tesourariacme.api.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;

@Entity
@Table(
    name = "service_closing_sessions",
    uniqueConstraints = @UniqueConstraint(columnNames = {"serviceDate", "serviceTime"})
)
@Data
@NoArgsConstructor
public class ServiceClosingSession {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_schedule_id", nullable = true)
    private ServiceSchedule serviceSchedule;

    @Column(nullable = false)
    private LocalDate serviceDate;

    private LocalTime serviceTime;

    private LocalTime serviceEndTime;

    private String serviceType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ServiceClosingSessionStatus status;

    @Column(nullable = false)
    private String startedBy;

    @Column(nullable = false)
    private LocalDateTime startedAt;

    @Column(nullable = false)
    private LocalDateTime expiresAt;

    @Column(nullable = false, columnDefinition = "boolean default false")
    private boolean lateOpening = false;

    @Column(columnDefinition = "TEXT")
    private String draftJson;
}
