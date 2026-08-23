package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.ServiceClosing;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.List;

@Repository
public interface ServiceClosingRepository extends JpaRepository<ServiceClosing, Long> {

    @Query("SELECT c FROM ServiceClosing c ORDER BY c.serviceDate DESC NULLS LAST, c.id DESC")
    List<ServiceClosing> findHistoryOrdered();

    List<ServiceClosing> findByServiceDateBetween(LocalDate startDate, LocalDate endDate);
}
