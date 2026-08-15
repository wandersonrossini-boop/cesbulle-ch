package com.tesourariacme.api.presentation;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;
import com.tesourariacme.api.domain.ServiceClosing;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ServiceClosingDetailResponse {
    private Long id;
    private LocalDate serviceDate;
    private String mainTreasurer;
    private String coTreasurer;
    private String verifierName;
    private String verifierType;
    
    private List<EnvelopeRequest> identifiedEntries;
    
    private BigDecimal unidentifiedDizimoTotal;
    private BigDecimal unidentifiedOfertaTotal;
    private BigDecimal unidentifiedVotoTotal;
    
    private BigDecimal identifiedTotal;
    private BigDecimal unidentifiedTotal;
    private BigDecimal registeredTotal;
    private BigDecimal physicalTotal;
    
    public static ServiceClosingDetailResponse fromEntity(ServiceClosing entity) {
        ServiceClosingDetailResponse dto = new ServiceClosingDetailResponse();
        dto.setId(entity.getId());
        dto.setServiceDate(entity.getServiceDate());
        dto.setMainTreasurer(entity.getMainTreasurer());
        dto.setCoTreasurer(entity.getCoTreasurer());

        String vName = entity.getVerifierName();
        String vType = entity.getVerifierType() != null ? entity.getVerifierType().name() : null;
        if (vName == null && entity.getCoTreasurer() != null && !entity.getCoTreasurer().trim().isEmpty()) {
            vName = entity.getCoTreasurer();
            vType = "LEGACY";
        }
        dto.setVerifierName(vName);
        dto.setVerifierType(vType);
        dto.setPhysicalTotal(entity.getPhysicalTotal());
        dto.setIdentifiedTotal(entity.getIdentifiedTotal());
        dto.setUnidentifiedTotal(entity.getUnidentifiedTotal());
        dto.setRegisteredTotal(entity.getRegisteredTotal());
        dto.setUnidentifiedDizimoTotal(entity.getUnidentifiedDizimoTotal());
        dto.setUnidentifiedOfertaTotal(entity.getUnidentifiedOfertaTotal());
        dto.setUnidentifiedVotoTotal(entity.getUnidentifiedVotoTotal());
        
        if (entity.getIdentifiedEntries() != null) {
            dto.setIdentifiedEntries(entity.getIdentifiedEntries().stream().map(e -> {
                EnvelopeRequest req = new EnvelopeRequest();
                req.setMemberName(e.getMemberName());
                req.setType(e.getType());
                req.setAmount(e.getAmount());
                return req;
            }).collect(Collectors.toList()));
        }
        
        return dto;
    }
}
