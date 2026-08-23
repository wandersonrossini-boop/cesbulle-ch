package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.ServiceClosingAttachment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface ServiceClosingAttachmentRepository extends JpaRepository<ServiceClosingAttachment, Long> {
    Optional<ServiceClosingAttachment> findByIdAndServiceClosingId(Long id, Long serviceClosingId);
}
