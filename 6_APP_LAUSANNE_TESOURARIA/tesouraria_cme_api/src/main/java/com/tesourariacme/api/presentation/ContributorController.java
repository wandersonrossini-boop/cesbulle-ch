package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.ContributorService;
import com.tesourariacme.api.application.AttestationService;
import com.tesourariacme.api.domain.Contributor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/contributors")
public class ContributorController {

    private final ContributorService contributorService;
    private final AttestationService attestationService;
    private final com.tesourariacme.api.application.AuditLogService auditLogService;
    private final EnvelopeRepository envelopeRepository;

    public ContributorController(
            EnvelopeRepository envelopeRepository,
            ContributorService contributorService,
            AttestationService attestationService,
            com.tesourariacme.api.application.AuditLogService auditLogService) {
        this.contributorService = contributorService;
        this.attestationService = attestationService;
        this.auditLogService = auditLogService;
        this.envelopeRepository = envelopeRepository;
    }

    private boolean isAuthorizedToManage(Authentication authentication) {
        return authentication.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_TREASURER"));
    }

    @GetMapping
    public ResponseEntity<?> getAll(@RequestParam(value = "search", required = false) String search, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        List<Contributor> list = contributorService.getAll(search);
        List<Map<String, Object>> result = list.stream().map(c -> {
            Map<String, Object> map = new java.util.HashMap<>();
            map.put("id", c.getId());
            map.put("fullName", c.getFullName());
            map.put("address", c.getAddress());
            map.put("postalCode", c.getPostalCode());
            map.put("city", c.getCity());
            map.put("email", c.getEmail());
            map.put("phone", c.getPhone());
            map.put("contributorNumber", c.getContributorNumber());
            map.put("active", c.isActive());
            map.put("hasMovements", envelopeRepository.countByContributorId(c.getId()) > 0);
            return map;
        }).collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody Contributor contributor, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        try {
            return ResponseEntity.ok(contributorService.create(contributor));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PutMapping("/{id}")
        @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        try {
            contributorService.delete(id);
            auditLogService.logAction("CONTRIBUTOR_DELETED", authentication.getName(), String.valueOf(id), "Contribuinte removido/desativado.");
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody Contributor contributor, Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        try {
            return ResponseEntity.ok(contributorService.update(id, contributor));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/{id}/annual-summary")
    public ResponseEntity<?> getAnnualSummary(
            @PathVariable Long id,
            @RequestParam("year") int year,
            Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        try {
            return ResponseEntity.ok(attestationService.generateAnnualSummary(id, year));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(e.getMessage());
        }
    }

    @GetMapping("/{id}/attestation/pdf")
    public ResponseEntity<?> getAttestationPdf(
            @PathVariable Long id,
            @RequestParam("year") int year,
            Authentication authentication) {
        if (!isAuthorizedToManage(authentication)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Acesso negado.");
        }
        try {
            byte[] pdfBytes = attestationService.generateAttestationPdf(id, year);
            auditLogService.logAction("ATTESTATION_GENERATED", authentication.getName(), String.valueOf(id), String.format("Atestado fiscal gerado para o ano %d", year));
            return ResponseEntity.ok()
                    .header("Content-Type", "application/pdf")
                    .header("Content-Disposition", String.format("inline; filename=attestation_%d.pdf", year))
                    .body(pdfBytes);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(e.getMessage());
        }
    }
}


