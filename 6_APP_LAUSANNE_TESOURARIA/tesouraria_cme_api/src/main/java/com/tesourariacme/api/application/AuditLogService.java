package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.AuditLog;
import com.tesourariacme.api.infrastructure.AuditLogRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;

@Service
public class AuditLogService {

    private final AuditLogRepository repository;

    public AuditLogService(AuditLogRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public void logAction(String action, String performedBy, String targetId, String details) {
        AuditLog log = new AuditLog();
        log.setAction(action);
        log.setPerformedBy(performedBy != null ? performedBy : "SYSTEM");
        log.setTargetId(targetId);
        log.setDetails(details);
        log.setTimestamp(LocalDateTime.now());
        repository.save(log);
    }

    public Page<AuditLog> getLogs(Pageable pageable) {
        return repository.findAllByOrderByTimestampDesc(pageable);
    }
}
