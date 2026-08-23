package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.SubmitServiceClosingUseCase;
import com.tesourariacme.api.application.ServiceClosingSessionService;
import com.tesourariacme.api.domain.Envelope;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.domain.ServiceClosingSession;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.beans.factory.annotation.Autowired;

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
    @Autowired
    private com.tesourariacme.api.infrastructure.ServiceClosingAttachmentRepository attachmentRepository;
    @Autowired
    private com.tesourariacme.api.infrastructure.StorageService storageService;

    @PostMapping("/{closingId}/attachments")
    public ResponseEntity<?> uploadAttachment(
            @PathVariable Long closingId,
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file,
            @RequestParam("documentType") com.tesourariacme.api.domain.DocumentType documentType,
            org.springframework.security.core.Authentication authentication) {

        return repository.findById(closingId).map(closing -> {
            if ("REJECTED".equals(closing.getStatus())) {
                return ResponseEntity.status(org.springframework.http.HttpStatus.BAD_REQUEST)
                        .body("Nao eh permitido adicionar anexos a fechamentos rejeitados.");
            }

            if (file.isEmpty()) {
                return ResponseEntity.badRequest().body("Arquivo vazio.");
            }
            if (file.getSize() > 5 * 1024 * 1024) {
                return ResponseEntity.badRequest().body("Tamanho maximo permitido eh 5MB.");
            }

            String contentType = file.getContentType();
            String originalFilename = file.getOriginalFilename();
            String ext = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                ext = originalFilename.substring(originalFilename.lastIndexOf(".") + 1).toLowerCase();
            }

            boolean validMime = "application/pdf".equals(contentType)
                    || "image/jpeg".equals(contentType)
                    || "image/png".equals(contentType);
            boolean validExt = "pdf".equals(ext) || "jpg".equals(ext) || "jpeg".equals(ext) || "png".equals(ext);

            if (!validMime || !validExt) {
                return ResponseEntity.badRequest().body("Formato nao suportado. Apenas PDF, JPG, PNG.");
            }

            String uuid = java.util.UUID.randomUUID().toString();
            String storagePath = "closings/" + closingId + "/" + uuid + "." + ext;

            try {
                storageService.save(storagePath, file);

                com.tesourariacme.api.domain.ServiceClosingAttachment attachment = new com.tesourariacme.api.domain.ServiceClosingAttachment();
                attachment.setServiceClosing(closing);
                attachment.setDocumentType(documentType);
                attachment.setFileName(originalFilename);
                attachment.setContentType(contentType);
                attachment.setStoragePath(storagePath);
                attachment.setFileSize(file.getSize());
                attachment.setUploadedBy(authentication.getName());
                attachment.setUploadedAt(java.time.LocalDateTime.now());
                attachment.setActive(true);

                com.tesourariacme.api.domain.ServiceClosingAttachment saved = attachmentRepository.save(attachment);
                
                closing.getAttachments().add(saved);
                repository.save(closing);

                return ResponseEntity.status(org.springframework.http.HttpStatus.CREATED).body(saved);
            } catch (Exception e) {
                return ResponseEntity.status(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR)
                        .body("Erro ao salvar arquivo: " + e.getMessage());
            }
        }).orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{closingId}/attachments/{attachmentId}")
    public ResponseEntity<?> downloadAttachment(
            @PathVariable Long closingId,
            @PathVariable Long attachmentId) {

        java.util.Optional<com.tesourariacme.api.domain.ServiceClosingAttachment> attachmentOpt = attachmentRepository.findByIdAndServiceClosingId(attachmentId, closingId);
        if (attachmentOpt.isEmpty()) {
            return ResponseEntity.status(org.springframework.http.HttpStatus.NOT_FOUND)
                    .body("Anexo nao encontrado.");
        }

        com.tesourariacme.api.domain.ServiceClosingAttachment attachment = attachmentOpt.get();
        if (!attachment.isActive()) {
            return ResponseEntity.status(org.springframework.http.HttpStatus.NOT_FOUND).body("Anexo desativado.");
        }

        try {
            byte[] data = storageService.load(attachment.getStoragePath());
            return ResponseEntity.ok()
                    .header("Content-Type", attachment.getContentType())
                    .header("Content-Disposition", "inline; filename=\"" + attachment.getFileName() + "\"" )
                    .body(data);
        } catch (Exception e) {
            return ResponseEntity.status(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Erro ao ler arquivo: " + e.getMessage());
        }
    }

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

    /**
     * Lists past schedule occurrences without a FINISHED session/closing.
     * withinDays: how many days back to search (required — Gatekeeper defines the value).
     */
    @GetMapping("/session/pending-occurrences")
    public ResponseEntity<?> getPendingOccurrences(@org.springframework.web.bind.annotation.RequestParam int withinDays) {
        try {
            java.util.List<java.util.Map<String, Object>> raw = sessionService.findPendingOccurrences(withinDays);
            // Project to a serialization-safe structure (avoid lazy-load issues with ServiceSchedule)
            java.util.List<java.util.Map<String, Object>> out = new java.util.ArrayList<>();
            for (java.util.Map<String, Object> entry : raw) {
                com.tesourariacme.api.domain.ServiceSchedule sched =
                        (com.tesourariacme.api.domain.ServiceSchedule) entry.get("schedule");
                java.util.Map<String, Object> item = new java.util.HashMap<>();
                item.put("scheduleId", sched.getId());
                item.put("serviceType", sched.getServiceType());
                item.put("startTime", sched.getStartTime().toString());
                item.put("endTime", sched.getEndTime().toString());
                item.put("date", entry.get("date"));
                item.put("sessionStatus", entry.get("sessionStatus"));
                item.put("sessionId", entry.get("sessionId"));
                out.add(item);
            }
            return ResponseEntity.ok(out);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Erro ao buscar ocorrências pendentes: " + e.getMessage());
        }
    }

    /**
     * Creates or resumes a late session.
     * Data/time/type come exclusively from the schedule — the client only provides scheduleId + date.
     */
    @PostMapping("/session/late")
    public ResponseEntity<?> createLateSession(@RequestBody LateSessionRequest request, Authentication authentication) {
        if (request.getDate() != null && monthlyPeriodService.isPeriodLocked(request.getDate())) {
            return ResponseEntity.badRequest().body("O período contábil deste mês está trancado para auditoria.");
        }
        try {
            String user = authentication != null ? authentication.getName() : "anonymous";
            ServiceClosingSession session = sessionService.createOrResumeLateSession(
                    request.getScheduleId(), request.getDate(), user);
            return ResponseEntity.ok(ServiceClosingSessionResponse.fromEntity(session));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
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
    public static class LateSessionRequest {
        private Long scheduleId;
        private LocalDate date;
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
        private boolean lateOpening;

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
            resp.setLateOpening(session.isLateOpening());
            return resp;
        }
    }
}




