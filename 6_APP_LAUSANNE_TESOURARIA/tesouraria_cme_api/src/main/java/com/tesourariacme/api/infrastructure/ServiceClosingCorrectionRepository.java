package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.ServiceClosingCorrection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface ServiceClosingCorrectionRepository extends JpaRepository<ServiceClosingCorrection, Long> {
    List<ServiceClosingCorrection> findByServiceClosingIdOrderByCreatedAtDesc(Long serviceClosingId);
}
