package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.ServiceClosingCorrection;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ServiceClosingCorrectionResponse {
    private Long id;
    private Long serviceClosingId;
    private BigDecimal originalPhysicalTotal;
    private BigDecimal correctedPhysicalTotal;
    private BigDecimal difference;
    private String reason;
    private String correctedBy;
    private LocalDateTime createdAt;
    private String beforeSnapshotJson;
    private String afterSnapshotJson;

    public static ServiceClosingCorrectionResponse fromEntity(ServiceClosingCorrection entity) {
        ServiceClosingCorrectionResponse resp = new ServiceClosingCorrectionResponse();
        resp.setId(entity.getId());
        resp.setServiceClosingId(entity.getServiceClosing() != null ? entity.getServiceClosing().getId() : null);
        resp.setOriginalPhysicalTotal(entity.getOriginalPhysicalTotal());
        resp.setCorrectedPhysicalTotal(entity.getCorrectedPhysicalTotal());
        resp.setDifference(entity.getDifference());
        resp.setReason(entity.getReason());
        resp.setCorrectedBy(entity.getCorrectedBy());
        resp.setCreatedAt(entity.getCreatedAt());
        resp.setBeforeSnapshotJson(entity.getBeforeSnapshotJson());
        resp.setAfterSnapshotJson(entity.getAfterSnapshotJson());
        return resp;
    }
}
