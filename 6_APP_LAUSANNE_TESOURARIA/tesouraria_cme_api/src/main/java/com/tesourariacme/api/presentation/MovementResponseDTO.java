package com.tesourariacme.api.presentation;

import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
public class MovementResponseDTO {
    private String reference; // e.g. "08/2026"
    private BigDecimal totalIncomes;
    private BigDecimal totalOutcomes;
    private BigDecimal balance;
    private List<MovementDTO> items;
}
