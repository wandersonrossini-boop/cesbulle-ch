package com.tesourariacme.api.presentation;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ServiceClosingCorrectionRequest {
    private String reason;
    private BigDecimal physicalTotal;
    private BigDecimal unidentifiedDizimoTotal;
    private BigDecimal unidentifiedOfertaTotal;
    private BigDecimal unidentifiedVotoTotal;
    private BigDecimal unidentifiedDinheiroTotal;
    private BigDecimal unidentifiedTwintTotal;
    private BigDecimal unidentifiedTransferenciaTotal;
    private List<EnvelopeRequest> identifiedEntries;
    private String verifierName;
    private com.tesourariacme.api.domain.VerifierType verifierType;
}
