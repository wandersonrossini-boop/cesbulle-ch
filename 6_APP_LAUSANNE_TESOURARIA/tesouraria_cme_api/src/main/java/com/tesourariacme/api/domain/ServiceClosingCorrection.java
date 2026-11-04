package com.tesourariacme.api.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "service_closing_corrections", indexes = {
    @Index(name = "idx_closing_correction_closing_id", columnList = "service_closing_id"),
    @Index(name = "idx_closing_correction_created_at", columnList = "createdAt")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ServiceClosingCorrection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "service_closing_id", nullable = false)
    private ServiceClosing serviceClosing;

    @Column(nullable = false)
    private BigDecimal originalPhysicalTotal;

    @Column(nullable = false)
    private BigDecimal correctedPhysicalTotal;

    @Column(nullable = false)
    private BigDecimal difference;

    @Column(nullable = false, length = 1000)
    private String reason;

    @Column(nullable = false)
    private String correctedBy;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @Column(columnDefinition = "TEXT")
    private String beforeSnapshotJson;

    @Column(columnDefinition = "TEXT")
    private String afterSnapshotJson;
}
