package com.tesourariacme.api.presentation;

import com.tesourariacme.api.domain.EnvelopeType;
import com.tesourariacme.api.domain.PaymentMethod;
import lombok.Data;
import java.math.BigDecimal;

@Data
public class EnvelopeRequest {
    private String memberName;
    private EnvelopeType type;
    private BigDecimal amount;
    private Long contributorId;
    private PaymentMethod paymentMethod = PaymentMethod.DINHEIRO;
}
