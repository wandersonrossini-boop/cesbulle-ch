package com.tesourariacme.api.application;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tesourariacme.api.domain.*;
import com.tesourariacme.api.infrastructure.AppUserRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingCorrectionRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.presentation.ServiceClosingCorrectionRequest;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class CorrectServiceClosingUseCase {

    private final ServiceClosingRepository closingRepository;
    private final ServiceClosingCorrectionRepository correctionRepository;
    private final AppUserRepository userRepository;
    private final MonthlyPeriodService monthlyPeriodService;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    public CorrectServiceClosingUseCase(
            ServiceClosingRepository closingRepository,
            ServiceClosingCorrectionRepository correctionRepository,
            AppUserRepository userRepository,
            MonthlyPeriodService monthlyPeriodService,
            AuditLogService auditLogService,
            ObjectMapper objectMapper) {
        this.closingRepository = closingRepository;
        this.correctionRepository = correctionRepository;
        this.userRepository = userRepository;
        this.monthlyPeriodService = monthlyPeriodService;
        this.auditLogService = auditLogService;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public ServiceClosingCorrection execute(Long closingId, ServiceClosingCorrectionRequest request, String username) {
        if (request.getReason() == null || request.getReason().trim().isEmpty()) {
            throw new IllegalArgumentException("A justificativa para a correção é obrigatória.");
        }

        AppUser user = userRepository.findByUsername(username)
                .orElseThrow(() -> new AccessDeniedException("Usuário não encontrado."));

        if (!user.isAuthorized()) {
            throw new AccessDeniedException("Usuário sem permissão ativa para executar correções.");
        }

        String role = user.getRole() != null ? user.getRole().toUpperCase() : "";
        if (!"ADMIN".equals(role) && !"PASTOR".equals(role) && !"TESOUREIRO".equals(role)) {
            throw new AccessDeniedException("Apenas usuários autorizados (ADMIN/PASTOR/TESOUREIRO) podem corrigir fechamentos confirmados.");
        }

        ServiceClosing closing = closingRepository.findById(closingId)
                .orElseThrow(() -> new IllegalArgumentException("Fechamento não encontrado: " + closingId));

        if (monthlyPeriodService.isPeriodLocked(closing.getServiceDate())) {
            throw new IllegalStateException("O período contábil deste mês está trancado para auditoria. Não é permitida retificação.");
        }

        String beforeSnapshotJson = "";
        try {
            beforeSnapshotJson = objectMapper.writeValueAsString(closing);
        } catch (Exception e) {
            beforeSnapshotJson = "{}";
        }

        BigDecimal originalPhysicalTotal = closing.getPhysicalTotal() != null ? closing.getPhysicalTotal() : BigDecimal.ZERO;

        if (request.getPhysicalTotal() != null) {
            closing.setPhysicalTotal(request.getPhysicalTotal());
        }
        if (request.getUnidentifiedDizimoTotal() != null) {
            closing.setUnidentifiedDizimoTotal(request.getUnidentifiedDizimoTotal());
        }
        if (request.getUnidentifiedOfertaTotal() != null) {
            closing.setUnidentifiedOfertaTotal(request.getUnidentifiedOfertaTotal());
        }
        if (request.getUnidentifiedVotoTotal() != null) {
            closing.setUnidentifiedVotoTotal(request.getUnidentifiedVotoTotal());
        }
        if (request.getUnidentifiedDinheiroTotal() != null) {
            closing.setUnidentifiedDinheiroTotal(request.getUnidentifiedDinheiroTotal());
        }
        if (request.getUnidentifiedTwintTotal() != null) {
            closing.setUnidentifiedTwintTotal(request.getUnidentifiedTwintTotal());
        }
        if (request.getUnidentifiedTransferenciaTotal() != null) {
            closing.setUnidentifiedTransferenciaTotal(request.getUnidentifiedTransferenciaTotal());
        }
        if (request.getVerifierName() != null && !request.getVerifierName().trim().isEmpty()) {
            closing.setVerifierName(request.getVerifierName().trim());
        }
        if (request.getVerifierType() != null) {
            closing.setVerifierType(request.getVerifierType());
        }

        if (request.getIdentifiedEntries() != null) {
            closing.getIdentifiedEntries().clear();
            List<Envelope> newEntries = request.getIdentifiedEntries().stream().map(req -> {
                Envelope env = new Envelope();
                env.setMemberName(req.getMemberName());
                env.setType(req.getType());
                env.setAmount(req.getAmount());
                env.setContributorId(req.getContributorId());
                env.setPaymentMethod(req.getPaymentMethod() != null ? req.getPaymentMethod() : PaymentMethod.DINHEIRO);
                return env;
            }).collect(Collectors.toList());
            closing.getIdentifiedEntries().addAll(newEntries);
        }

        closing.calculateTotalsAndValidate();
        ServiceClosing updatedClosing = closingRepository.save(closing);

        BigDecimal correctedPhysicalTotal = updatedClosing.getPhysicalTotal();
        BigDecimal diff = correctedPhysicalTotal.subtract(originalPhysicalTotal);

        String afterSnapshotJson = "";
        try {
            afterSnapshotJson = objectMapper.writeValueAsString(updatedClosing);
        } catch (Exception e) {
            afterSnapshotJson = "{}";
        }

        ServiceClosingCorrection correction = new ServiceClosingCorrection();
        correction.setServiceClosing(updatedClosing);
        correction.setOriginalPhysicalTotal(originalPhysicalTotal);
        correction.setCorrectedPhysicalTotal(correctedPhysicalTotal);
        correction.setDifference(diff);
        correction.setReason(request.getReason().trim());
        correction.setCorrectedBy(username);
        correction.setCreatedAt(LocalDateTime.now());
        correction.setBeforeSnapshotJson(beforeSnapshotJson);
        correction.setAfterSnapshotJson(afterSnapshotJson);

        ServiceClosingCorrection savedCorrection = correctionRepository.save(correction);

        auditLogService.logAction(
                "CLOSING_CORRECTED",
                username,
                String.valueOf(updatedClosing.getId()),
                String.format("Fechamento corrigido: Original CHF %s -> Corrigido CHF %s (Dif CHF %s). Motivo: %s",
                        originalPhysicalTotal, correctedPhysicalTotal, diff, request.getReason().trim())
        );

        return savedCorrection;
    }

    public List<ServiceClosingCorrection> getCorrections(Long closingId) {
        return correctionRepository.findByServiceClosingIdOrderByCreatedAtDesc(closingId);
    }
}
