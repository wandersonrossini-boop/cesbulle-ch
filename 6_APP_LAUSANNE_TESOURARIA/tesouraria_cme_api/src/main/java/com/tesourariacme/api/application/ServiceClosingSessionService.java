package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.ServiceClosingSession;
import com.tesourariacme.api.domain.ServiceClosingSessionStatus;
import com.tesourariacme.api.infrastructure.ServiceClosingSessionRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.tesourariacme.api.domain.ServiceSchedule;
import com.tesourariacme.api.infrastructure.ServiceScheduleRepository;
import java.time.DayOfWeek;
import java.util.List;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;

@Service
public class ServiceClosingSessionService {

    private final ServiceClosingSessionRepository repository;
    private final ServiceScheduleRepository scheduleRepository;

    public ServiceClosingSessionService(ServiceClosingSessionRepository repository, ServiceScheduleRepository scheduleRepository) {
        this.repository = repository;
        this.scheduleRepository = scheduleRepository;
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
        
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Europe/Zurich"));
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
            if (LocalDateTime.now(ZoneId.of("Europe/Zurich")).isAfter(session.getExpiresAt())) {
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

    public Optional<ServiceSchedule> findScheduleForTime(LocalDateTime dateTime) {
        DayOfWeek day = dateTime.getDayOfWeek();
        LocalTime time = dateTime.toLocalTime();
        
        List<ServiceSchedule> schedules = scheduleRepository.findByDayOfWeekAndActiveTrue(day);
        
        ServiceSchedule matched = null;
        long minDistanceMinutes = Long.MAX_VALUE;
        
        for (ServiceSchedule sched : schedules) {
            // Janela operacional: do início do culto até +60 minutos pós-término
            LocalTime windowStart = sched.getStartTime();
            LocalTime windowEnd = sched.getEndTime().plusMinutes(60);
            
            boolean inWindow = false;
            if (windowStart.isBefore(windowEnd)) {
                inWindow = !time.isBefore(windowStart) && !time.isAfter(windowEnd);
            } else {
                inWindow = !time.isBefore(windowStart) || !time.isAfter(windowEnd);
            }
            
            if (inWindow) {
                long dist = java.time.temporal.ChronoUnit.MINUTES.between(sched.getStartTime(), time);
                long absDist = Math.abs(dist);
                if (absDist < minDistanceMinutes) {
                    minDistanceMinutes = absDist;
                    matched = sched;
                }
            }
        }
        return Optional.ofNullable(matched);
    }

    @Transactional
    public ServiceClosingSession resolveOrCreateSession(LocalDateTime dateTime, String user) {
        ServiceSchedule schedule = findScheduleForTime(dateTime)
                .orElseThrow(() -> new IllegalArgumentException("Nenhum culto aplicável"));

        LocalDate date = dateTime.toLocalDate();
        
        Optional<ServiceClosingSession> existingOpt = repository.findByServiceScheduleAndServiceDate(schedule, date);
        if (existingOpt.isPresent()) {
            return handleExistingSession(existingOpt.get());
        }

        // Tentar encontrar legado pelo mesmo dia/hora de início
        Optional<ServiceClosingSession> legacyOpt = repository.findByServiceDateAndServiceTime(date, schedule.getStartTime());
        if (legacyOpt.isPresent()) {
            ServiceClosingSession legacy = legacyOpt.get();
            if (legacy.getServiceSchedule() == null) {
                legacy.setServiceSchedule(schedule);
                repository.saveAndFlush(legacy);
            }
            return handleExistingSession(legacy);
        }

        ServiceClosingSession session = new ServiceClosingSession();
        session.setServiceSchedule(schedule);
        session.setServiceDate(date);
        session.setServiceTime(schedule.getStartTime());
        session.setServiceEndTime(schedule.getEndTime());
        session.setServiceType(schedule.getServiceType());
        session.setStatus(ServiceClosingSessionStatus.ACTIVE);
        session.setStartedBy(user);
        session.setStartedAt(LocalDateTime.now(ZoneId.of("Europe/Zurich")));
        session.setExpiresAt(calculateExpirationPolicy(date, schedule.getEndTime()));

        try {
            return repository.saveAndFlush(session);
        } catch (DataIntegrityViolationException e) {
            return repository.findByServiceScheduleAndServiceDate(schedule, date)
                    .map(this::handleExistingSession)
                    .orElseGet(() -> repository.findByServiceDateAndServiceTime(date, schedule.getStartTime())
                            .map(this::handleExistingSession)
                            .orElseThrow(() -> e));
        }
    }

    public Optional<ServiceClosingSession> findSessionByScheduleAndDate(ServiceSchedule schedule, LocalDate date) {
        Optional<ServiceClosingSession> opt = repository.findByServiceScheduleAndServiceDate(schedule, date);
        if (opt.isPresent()) {
            return opt;
        }
        return repository.findByServiceDateAndServiceTime(date, schedule.getStartTime());
    }
}
