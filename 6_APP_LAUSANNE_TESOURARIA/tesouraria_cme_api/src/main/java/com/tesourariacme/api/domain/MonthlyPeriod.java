package com.tesourariacme.api.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.time.LocalDateTime;

@Entity
@Table(name = "monthly_periods", uniqueConstraints = {
    @UniqueConstraint(columnNames = {"year", "month"})
}, indexes = {
    @Index(name = "idx_monthly_period_ym", columnList = "year, month")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
public class MonthlyPeriod {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private int year;

    @Column(nullable = false)
    private int month;

    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private PeriodStatus status = PeriodStatus.OPEN;

    private String lockedBy;
    private LocalDateTime lockedAt;

    public enum PeriodStatus {
        OPEN, LOCKED
    }
}
