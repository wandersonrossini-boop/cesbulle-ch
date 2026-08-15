package com.tesourariacme.api.presentation;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
public class ServiceClosingRequest {
    private LocalDate serviceDate;
    private String mainTreasurer;
    private String coTreasurer;
    private String verifierName;
    private com.tesourariacme.api.domain.VerifierType verifierType;
    private List<EnvelopeRequest> identifiedEntries;
    private BigDecimal physicalTotal;
    private BigDecimal unidentifiedDizimoTotal;
    private BigDecimal unidentifiedOfertaTotal;
    private BigDecimal unidentifiedVotoTotal;
}
