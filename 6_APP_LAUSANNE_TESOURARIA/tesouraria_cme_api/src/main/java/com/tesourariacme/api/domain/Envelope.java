package com.tesourariacme.api.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import java.math.BigDecimal;

@Entity
@Table(name = "envelopes", indexes = {
    @Index(name = "idx_envelope_contrib_id", columnList = "contributorId")
})
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Envelope {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String memberName;
    
    @Enumerated(EnumType.STRING)
    private EnvelopeType type;
    
    private BigDecimal amount;
    
    private Long contributorId;

    public Envelope(Long id, String memberName, EnvelopeType type, BigDecimal amount) {
        this.id = id;
        this.memberName = memberName;
        this.type = type;
        this.amount = amount;
    }
}
