package com.tesourariacme.api.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

@Entity
@Table(name = "envelopes", indexes = {
    @Index(name = "idx_envelope_contrib_id", columnList = "contributorId")
})
@Data
@NoArgsConstructor
public class Envelope {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String memberName;
    
    @Enumerated(EnumType.STRING)
    private EnvelopeType type;
    
    private BigDecimal amount;
    
    private Long contributorId;

    @Enumerated(EnumType.STRING)
    private PaymentMethod paymentMethod = PaymentMethod.DINHEIRO;

    public Envelope(Long id, String memberName, EnvelopeType type, BigDecimal amount) {
        this.id = id;
        this.memberName = memberName;
        this.type = type;
        this.amount = amount;
        this.paymentMethod = PaymentMethod.DINHEIRO;
    }

    public Envelope(Long id, String memberName, EnvelopeType type, BigDecimal amount, Long contributorId, PaymentMethod paymentMethod) {
        this.id = id;
        this.memberName = memberName;
        this.type = type;
        this.amount = amount;
        this.contributorId = contributorId;
        this.paymentMethod = (paymentMethod != null) ? paymentMethod : PaymentMethod.DINHEIRO;
    }
}
