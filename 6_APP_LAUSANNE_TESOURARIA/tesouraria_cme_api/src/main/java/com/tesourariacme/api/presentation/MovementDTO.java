package com.tesourariacme.api.presentation;

import lombok.Data;
import lombok.Builder;
import java.math.BigDecimal;
import java.time.LocalDate;

@Data
@Builder
public class MovementDTO {
    private String id;
    private LocalDate date;
    private String type; // "INCOME" or "OUTCOME"
    private String category;
    private String description;
    private BigDecimal value;
    private String status; // "APPROVED", "PAID", "COMPLETED"
}
