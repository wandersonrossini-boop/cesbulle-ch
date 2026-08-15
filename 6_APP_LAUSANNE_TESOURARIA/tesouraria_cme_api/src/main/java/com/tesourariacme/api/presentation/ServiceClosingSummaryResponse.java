package com.tesourariacme.api.presentation;

import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ServiceClosingSummaryResponse {
    private Long id;
    private LocalDate serviceDate;
    private String mainTreasurer;
    private String coTreasurer;
    private String verifierName;
    private String verifierType;
    private BigDecimal physicalTotal;
    
    // Status can be determined by the client (if difference is 0, it is "Conferido"), 
    // or we can pass difference explicitly if we had it, but since we reject difference != 0 on save,
    // any saved closing is implicitly "Conferido" (Difference = 0).
}
