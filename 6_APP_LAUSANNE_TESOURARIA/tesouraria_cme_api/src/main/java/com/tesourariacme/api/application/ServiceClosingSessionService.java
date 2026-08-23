package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.ServiceClosingSession;
import com.tesourariacme.api.domain.ServiceClosingSessionStatus;
import com.tesourariacme.api.infrastructure.ServiceClosingSessionRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.tesourariacme.api.domain.ServiceSchedule;
import com.tesourariacme.api.infrastructure.ServiceScheduleRepository;
import java.time.DayOfWeek;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;

@Service
public class ServiceClosingSessionService {

    private final ServiceClosingSessionRepository repository;
    private final ServiceScheduleRepository scheduleRepository;
    private final ServiceClosingRepository closingRepository;
    private final AuditLogService auditLogService;

    public ServiceClosingSessionService(
            ServiceClosingSessionRepository repository,
            ServiceScheduleRepository scheduleRepository,
            ServiceClosingRepository closingRepository,
            AuditLogService auditLogService) {
        this.repository = repository;
        this.scheduleRepository = scheduleRepository;
        this.closingRepository = closingRepository;
        this.auditLogService = auditLogService;
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

    /**
     * Returns schedule occurrences in the past [withinDays] days that have no FINISHED session/closing.
     * Excludes: future dates, today-in-active-window (handled by normal flow), already FINISHED sessions.
     *
     * Each entry contains:
     *   - schedule: the ServiceSchedule
     *   - date: the concrete LocalDate of the occurrence
     *   - sessionStatus: "NO_SESSION" | "ACTIVE" | "PENDING_CLOSE"
     *   - sessionId: Long or null
     */
    public List<Map<String, Object>> findPendingOccurrences(int withinDays) {
        LocalDate today = LocalDate.now(ZoneId.of("Europe/Zurich"));
        LocalDateTime now = LocalDateTime.now(ZoneId.of("Europe/Zurich"));
        LocalDate since = today.minusDays(withinDays);

        List<ServiceSchedule> activeSchedules = scheduleRepository.findByActiveTrue();
        List<Map<String, Object>> result = new ArrayList<>();

        for (ServiceSchedule schedule : activeSchedules) {
            // Iterate each day in the window
            LocalDate cursor = since;
            while (!cursor.isAfter(today)) {
                if (cursor.getDayOfWeek() == schedule.getDayOfWeek()) {
                    // Skip today if still inside the automatic window (+60 min after end)
                    if (cursor.equals(today)) {
                        LocalDateTime windowEnd = LocalDateTime.of(today, schedule.getEndTime()).plusMinutes(60);
                        if (!now.isAfter(windowEnd)) {
                            cursor = cursor.plusDays(1);
                            continue;
                        }
                    }

                    // Check if there is already a closing (FINISHED) for this occurrence
                    LocalDate occDate = cursor;
                    boolean hasClosing = closingRepository.findByServiceDateBetween(occDate, occDate)
                            .stream().anyMatch(c -> occDate.equals(c.getServiceDate()));

                    if (hasClosing) {
                        cursor = cursor.plusDays(1);
                        continue;
                    }

                    // Check session status
                    Optional<ServiceClosingSession> sessionOpt = findSessionByScheduleAndDate(schedule, occDate);

                    if (sessionOpt.isPresent()) {
                        ServiceClosingSession session = sessionOpt.get();
                        if (session.getStatus() == ServiceClosingSessionStatus.FINISHED) {
                            cursor = cursor.plusDays(1);
                            continue;
                        }
                        // ACTIVE or PENDING_CLOSE — show as "Continuar"
                        Map<String, Object> entry = new HashMap<>();
                        entry.put("schedule", schedule);
                        entry.put("date", occDate.toString());
                        entry.put("sessionStatus", session.getStatus().name());
                        entry.put("sessionId", session.getId());
                        result.add(entry);
                    } else {
                        // No session at all — show as "Registrar"
                        Map<String, Object> entry = new HashMap<>();
                        entry.put("schedule", schedule);
                        entry.put("date", occDate.toString());
                        entry.put("sessionStatus", "NO_SESSION");
                        entry.put("sessionId", null);
                        result.add(entry);
                    }
                }
                cursor = cursor.plusDays(1);
            }
        }

        // Most recent first
        result.sort((a, b) -> ((String) b.get("date")).compareTo((String) a.get("date")));
        return result;
    }

    /**
     * Creates or resumes a late session for a past occurrence of the given schedule on the given date.
     * Rules:
     *   - Date must be in the past (not today-in-window).
     *   - FINISHED session or existing closing → throw IllegalArgumentException.
     *   - Existing ACTIVE/PENDING_CLOSE session → resume (return existing).
     *   - No session → create with lateOpening=true and audit entry.
     */
    @Transactional
    public ServiceClosingSession createOrResumeLateSession(Long scheduleId, LocalDate date, String user) {
        LocalDate today = LocalDate.now(ZoneId.of("Europe/Zurich"));
        if (date.isAfter(today)) {
            throw new IllegalArgumentException("Não é possível criar contagem tardia para uma data futura.");
        }

        ServiceSchedule schedule = scheduleRepository.findById(scheduleId)
                .orElseThrow(() -> new IllegalArgumentException("Agenda não encontrada."));

        if (!schedule.isActive()) {
            throw new IllegalArgumentException("A agenda referenciada está inativa.");
        }

        // Guard: closing already exists for this date
        boolean hasClosing = closingRepository.findByServiceDateBetween(date, date)
                .stream().anyMatch(c -> date.equals(c.getServiceDate()));
        if (hasClosing) {
            throw new IllegalArgumentException("Já existe um fechamento registrado para esta ocorrência.");
        }

        // Guard: existing session
        Optional<ServiceClosingSession> existingOpt = findSessionByScheduleAndDate(schedule, date);
        if (existingOpt.isPresent()) {
            ServiceClosingSession existing = existingOpt.get();
            if (existing.getStatus() == ServiceClosingSessionStatus.FINISHED) {
                throw new IllegalArgumentException("O culto para a data e hora informadas já possui um fechamento concluído.");
            }
            // Resume: ACTIVE or PENDING_CLOSE
            return existing;
        }

        // Create new late session
        ServiceClosingSession session = new ServiceClosingSession();
        session.setServiceSchedule(schedule);
        session.setServiceDate(date);
        session.setServiceTime(schedule.getStartTime());
        session.setServiceEndTime(schedule.getEndTime());
        session.setServiceType(schedule.getServiceType());
        session.setStatus(ServiceClosingSessionStatus.ACTIVE);
        session.setStartedBy(user);
        session.setLateOpening(true);
        LocalDateTime nowDt = LocalDateTime.now(ZoneId.of("Europe/Zurich"));
        session.setStartedAt(nowDt);
        // expiresAt = now + 24h (gives working time without blocking the window logic)
        session.setExpiresAt(nowDt.plusHours(24));

        try {
            ServiceClosingSession saved = repository.saveAndFlush(session);
            auditLogService.logAction(
                    "LATE_OPENING",
                    user,
                    "session:" + saved.getId(),
                    "Abertura tardia para culto " + schedule.getServiceType()
                            + " em " + date + " (" + schedule.getStartTime() + "-" + schedule.getEndTime() + ")"
            );
            return saved;
        } catch (DataIntegrityViolationException e) {
            // Race condition: session was created concurrently
            return findSessionByScheduleAndDate(schedule, date)
                    .map(s -> {
                        if (s.getStatus() == ServiceClosingSessionStatus.FINISHED) {
                            throw new IllegalArgumentException("O culto para a data e hora informadas já possui um fechamento concluído.");
                        }
                        return s;
                    })
                    .orElseThrow(() -> e);
        }
    }
}
