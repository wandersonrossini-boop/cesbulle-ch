package com.tesourariacme.api.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDate;

import java.util.ArrayList;
import java.util.List;

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
    private String rejectedBy;
    private LocalDate rejectionDate;
    private String rejectionJustification;
    private String reversedBy;
    private LocalDate reversalDate;
    private String reversalJustification;
    private String approvedBy;
    private LocalDate approvalDate;
    @Column(length = 500)
    private String observations;

    @OneToMany(mappedBy = "expense", cascade = {CascadeType.PERSIST, CascadeType.MERGE})
    private List<ExpenseAttachment> attachments = new ArrayList<>();
}
