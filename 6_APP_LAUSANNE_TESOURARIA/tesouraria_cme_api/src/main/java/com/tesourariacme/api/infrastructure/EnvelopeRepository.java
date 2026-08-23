package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.Envelope;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface EnvelopeRepository extends JpaRepository<Envelope, Long> {

    @Query("SELECT e FROM ServiceClosing sc JOIN sc.identifiedEntries e WHERE e.contributorId = :contributorId " +
           "AND sc.serviceDate >= :startDate AND sc.serviceDate <= :endDate")
    List<Envelope> findByContributorIdAndDateRange(
            @Param("contributorId") Long contributorId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);
}
