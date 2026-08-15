package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.SubmitServiceClosingUseCase;
import com.tesourariacme.api.domain.Envelope;
import com.tesourariacme.api.domain.ServiceClosing;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/fechamento-culto")

public class ServiceClosingController {

    private final SubmitServiceClosingUseCase useCase;
    private static Object activeDraft = null; // static to persist across controller requests

    public ServiceClosingController(SubmitServiceClosingUseCase useCase) {
        this.useCase = useCase;
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
}
