package com.tesourariacme.api.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;

@Entity
@Data
@NoArgsConstructor
public class Expense {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private LocalDate expenseDate;
    private String description;
    private String supplier;
    private String category;
    private BigDecimal amount;
    private String paymentMethod;
    private String receiptReference;
    private String createdBy;
    private String status; // PENDING, APPROVED, REJECTED, REVERSED
    private String reversalJustification;
    private String approvedBy;
    private LocalDate approvalDate;
}
