package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.ServiceClosingSession;
import com.tesourariacme.api.domain.ServiceClosingSessionStatus;
import com.tesourariacme.api.infrastructure.ServiceClosingSessionRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class ServiceClosingSessionService {

    private final ServiceClosingSessionRepository repository;

    public ServiceClosingSessionService(ServiceClosingSessionRepository repository) {
        this.repository = repository;
    }

    public Optional<ServiceClosingSession> findById(Long id) {
        return repository.findById(id);
    }

    @Transactional
    public ServiceClosingSession getOrCreate(LocalDate date, LocalTime startTime, LocalTime endTime, String type, String user) {
        Optional<ServiceClosingSession> existingOpt = repository.findByServiceDateAndServiceTime(date, startTime);
        if (existingOpt.isPresent()) {
            return handleExistingSession(existingOpt.get());
        }

        ServiceClosingSession session = new ServiceClosingSession();
        session.setServiceDate(date);
        session.setServiceTime(startTime);
        session.setServiceEndTime(endTime);
        session.setServiceType(type);
        session.setStatus(ServiceClosingSessionStatus.ACTIVE);
        session.setStartedBy(user);
        
        LocalDateTime now = LocalDateTime.now();
        session.setStartedAt(now);
        session.setExpiresAt(calculateExpirationPolicy(date, endTime));

        try {
            return repository.saveAndFlush(session);
        } catch (DataIntegrityViolationException e) {
            // Corrida de criação: recupera a sessão vencedora salva concorrentemente
            return repository.findByServiceDateAndServiceTime(date, startTime)
                    .map(this::handleExistingSession)
                    .orElseThrow(() -> e);
        }
    }

    private ServiceClosingSession handleExistingSession(ServiceClosingSession session) {
        if (session.getStatus() == ServiceClosingSessionStatus.FINISHED) {
            throw new IllegalArgumentException("O culto para a data e hora informadas já possui um fechamento concluído.");
        }

        if (session.getStatus() == ServiceClosingSessionStatus.ACTIVE) {
            if (LocalDateTime.now().isAfter(session.getExpiresAt())) {
                session.setStatus(ServiceClosingSessionStatus.PENDING_CLOSE);
                return repository.saveAndFlush(session);
            }
        }

        return session;
    }

    /**
     * Política de expiração: expiresAt = serviceDate + serviceEndTime + 60 minutos.
     */
    private LocalDateTime calculateExpirationPolicy(LocalDate date, LocalTime endTime) {
        if (endTime == null) {
            // Fallback caso endTime não seja fornecido
            return LocalDateTime.of(date, LocalTime.MIDNIGHT).plusDays(1);
        }
        return LocalDateTime.of(date, endTime).plusMinutes(60);
    }

    public Optional<String> getDraft(Long sessionId) {
        return repository.findById(sessionId)
                .map(ServiceClosingSession::getDraftJson);
    }

    @Transactional
    public void saveDraft(Long sessionId, String draftJson) {
        ServiceClosingSession session = repository.findById(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("Sessão não encontrada."));
        if (session.getStatus() == ServiceClosingSessionStatus.FINISHED) {
            throw new IllegalStateException("Não é permitido alterar o rascunho de uma sessão finalizada.");
        }
        session.setDraftJson(draftJson);
        repository.saveAndFlush(session);
    }

    @Transactional
    public void clearDraft(Long sessionId) {
        ServiceClosingSession session = repository.findById(sessionId)
                .orElseThrow(() -> new IllegalArgumentException("Sessão não encontrada."));
        if (session.getStatus() == ServiceClosingSessionStatus.FINISHED) {
            throw new IllegalStateException("Não é permitido alterar o rascunho de uma sessão finalizada.");
        }
        session.setDraftJson(null);
        repository.saveAndFlush(session);
    }
}
