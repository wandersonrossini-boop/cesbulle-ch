package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.SubmitServiceClosingUseCase;
import com.tesourariacme.api.application.ServiceClosingSessionService;
import com.tesourariacme.api.domain.Envelope;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.domain.ServiceClosingSession;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.core.Authentication;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.LocalDateTime;
import java.util.stream.Collectors;
import java.util.Map;
import java.util.HashMap;
import java.util.Optional;
import com.tesourariacme.api.domain.ServiceSchedule;

@RestController
@RequestMapping("/api/fechamento-culto")

public class ServiceClosingController {

    private final SubmitServiceClosingUseCase useCase;
    private final ServiceClosingSessionService sessionService;
    private final ObjectMapper objectMapper;
    private final com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService;
    private static Object activeDraft = null; // static to persist across controller requests

    public ServiceClosingController(
            SubmitServiceClosingUseCase useCase,
            ServiceClosingSessionService sessionService,
            ObjectMapper objectMapper,
            com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService) {
        this.useCase = useCase;
        this.sessionService = sessionService;
        this.objectMapper = objectMapper;
        this.monthlyPeriodService = monthlyPeriodService;
    }

    @PostMapping("/draft")
    public ResponseEntity<?> saveDraft(@RequestBody Object draft) {
        activeDraft = draft;
        return ResponseEntity.ok().build();
    }

    @GetMapping("/draft")
    public ResponseEntity<?> getDraft() {
        if (activeDraft == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(activeDraft);
    }

    @DeleteMapping("/draft")
    public ResponseEntity<?> clearDraft() {
        activeDraft = null;
        return ResponseEntity.ok().build();
    }

    @PostMapping
    public ResponseEntity<?> submitClosing(@RequestBody ServiceClosingRequest request) {
        try {
            ServiceClosing closing = new ServiceClosing();
            closing.setServiceDate(request.getServiceDate());
            closing.setMainTreasurer(request.getMainTreasurer());
            closing.setCoTreasurer(request.getCoTreasurer());
            closing.setVerifierName(request.getVerifierName());
            closing.setVerifierType(request.getVerifierType());
            closing.setPhysicalTotal(request.getPhysicalTotal());
            closing.setUnidentifiedDizimoTotal(request.getUnidentifiedDizimoTotal());
            closing.setUnidentifiedOfertaTotal(request.getUnidentifiedOfertaTotal());
            closing.setUnidentifiedVotoTotal(request.getUnidentifiedVotoTotal());
            
            if (request.getIdentifiedEntries() != null) {
                closing.setIdentifiedEntries(request.getIdentifiedEntries().stream().map(req -> {
                    Envelope env = new Envelope();
                    env.setMemberName(req.getMemberName());
                    env.setType(req.getType());
                    env.setAmount(req.getAmount());
                    return env;
                }).collect(Collectors.toList()));
            }

            ServiceClosing saved = useCase.execute(closing);
            activeDraft = null; // Clear draft on successful submit
            return ResponseEntity.ok(saved);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping
    public ResponseEntity<?> getHistory() {
        return ResponseEntity.ok(useCase.getHistory());
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getById(@PathVariable Long id) {
        try {
            return ResponseEntity.ok(ServiceClosingDetailResponse.fromEntity(useCase.getById(id)));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteClosing(@PathVariable Long id) {
        try {
            useCase.deleteById(id);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @PostMapping("/session")
    public ResponseEntity<?> createSession(@RequestBody ServiceClosingSessionRequest request, Authentication authentication) {
        if (request.getServiceDate() != null && monthlyPeriodService.isPeriodLocked(request.getServiceDate())) {
            return ResponseEntity.badRequest().body("O período contábil deste mês está trancado para auditoria.");
        }
        if (request.getServiceDate() == null && monthlyPeriodService.isPeriodLocked(LocalDate.now())) {
            return ResponseEntity.badRequest().body("O período contábil deste mês está trancado para auditoria.");
        }
        try {
            String user = authentication != null ? authentication.getName() : "anonymous";
            ServiceClosingSession session;
            if (request.getServiceDate() == null) {
                session = sessionService.resolveOrCreateSession(LocalDateTime.now(), user);
            } else {
                session = sessionService.getOrCreate(
                        request.getServiceDate(),
                        request.getServiceTime(),
                        request.getServiceEndTime(),
                        request.getServiceType(),
                        user
                );
            }
            return ResponseEntity.ok(ServiceClosingSessionResponse.fromEntity(session));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/session/current-status")
    public ResponseEntity<?> getCurrentStatus() {
        LocalDateTime now = LocalDateTime.now();
        Optional<ServiceSchedule> scheduleOpt = sessionService.findScheduleForTime(now);
        Map<String, Object> response = new HashMap<>();
        
        if (scheduleOpt.isEmpty()) {
            response.put("hasSchedule", false);
            return ResponseEntity.ok(response);
        }
        
        ServiceSchedule schedule = scheduleOpt.get();
        LocalDate date = now.toLocalDate();
        Optional<ServiceClosingSession> sessionOpt = sessionService.findSessionByScheduleAndDate(schedule, date);
        
        response.put("hasSchedule", true);
        response.put("schedule", schedule);
        response.put("hasSession", sessionOpt.isPresent());
        if (sessionOpt.isPresent()) {
            response.put("session", ServiceClosingSessionResponse.fromEntity(sessionOpt.get()));
        }
        return ResponseEntity.ok(response);
    }

    @GetMapping("/session/{id}")
    public ResponseEntity<?> getSessionById(@PathVariable Long id) {
        return sessionService.findById(id)
                .map(session -> ResponseEntity.ok(ServiceClosingSessionResponse.fromEntity(session)))
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/session/{id}/draft")
    public ResponseEntity<?> saveSessionDraft(@PathVariable Long id, @RequestBody Object draft) {
        try {
            String jsonStr = objectMapper.writeValueAsString(draft);
            sessionService.saveDraft(id, jsonStr);
            return ResponseEntity.ok().build();
        } catch (IllegalStateException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Erro ao processar o rascunho: " + e.getMessage());
        }
    }

    @GetMapping("/session/{id}/draft")
    public ResponseEntity<?> getSessionDraft(@PathVariable Long id) {
        return sessionService.getDraft(id)
                .filter(draft -> draft != null && !draft.trim().isEmpty())
                .map(draft -> {
                    try {
                        Object obj = objectMapper.readValue(draft, Object.class);
                        return ResponseEntity.ok(obj);
                    } catch (Exception e) {
                        return ResponseEntity.internalServerError().build();
                    }
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/session/{id}/draft")
    public ResponseEntity<?> clearSessionDraft(@PathVariable Long id) {
        try {
            sessionService.clearDraft(id);
            return ResponseEntity.ok().build();
        } catch (IllegalStateException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @Data
    public static class ServiceClosingSessionRequest {
        private LocalDate serviceDate;
        private LocalTime serviceTime;
        private LocalTime serviceEndTime;
        private String serviceType;
    }

    @Data
    public static class ServiceClosingSessionResponse {
        private Long id;
        private LocalDate serviceDate;
        private LocalTime serviceTime;
        private LocalTime serviceEndTime;
        private String serviceType;
        private String status;
        private String startedBy;
        private LocalDateTime startedAt;
        private LocalDateTime expiresAt;

        public static ServiceClosingSessionResponse fromEntity(ServiceClosingSession session) {
            ServiceClosingSessionResponse resp = new ServiceClosingSessionResponse();
            resp.setId(session.getId());
            resp.setServiceDate(session.getServiceDate());
            resp.setServiceTime(session.getServiceTime());
            resp.setServiceEndTime(session.getServiceEndTime());
            resp.setServiceType(session.getServiceType());
            resp.setStatus(session.getStatus().name());
            resp.setStartedBy(session.getStartedBy());
            resp.setStartedAt(session.getStartedAt());
            resp.setExpiresAt(session.getExpiresAt());
            return resp;
        }
    }
}
