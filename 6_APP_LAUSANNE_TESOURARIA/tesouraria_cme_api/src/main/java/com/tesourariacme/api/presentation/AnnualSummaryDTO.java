package com.tesourariacme.api.presentation;

import lombok.Data;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AnnualSummaryDTO {
    private Long contributorId;
    private String fullName;
    private String contributorNumber;
    private String address;
    private String postalCode;
    private String city;
    private int year;
    private BigDecimal totalTithes;
    private BigDecimal totalVows;
    private BigDecimal totalConsolidated;
    private List<EntryDetail> details;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EntryDetail {
        private LocalDate date;
        private String type;
        private BigDecimal amount;
    }
}
