package com.tesourariacme.api.domain;

import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

public class ServiceClosingReconciliationTest {

    @Test
    public void testReconciliationComparesOnlyCashWithPhysicalTotal() {
        // Exemplo do documento de governança:
        // Dinheiro registrado: CHF 350
        // TWINT: CHF 100
        // Transferências: CHF 50
        // Total Geral: CHF 500
        // Dinheiro contado: CHF 350 -> Diferença de caixa: CHF 0 (Válido)

        ServiceClosing closing = new ServiceClosing();
        closing.setPhysicalTotal(new BigDecimal("350.00")); // Dinheiro físico contado

        List<Envelope> envelopes = new ArrayList<>();
        // Dízimo de 200 em Dinheiro
        envelopes.add(new Envelope(1L, "Membro 1", EnvelopeType.DIZIMO, new BigDecimal("200.00"), null, PaymentMethod.DINHEIRO));
        // Oferta de 100 em TWINT
        envelopes.add(new Envelope(2L, "Membro 2", EnvelopeType.OFERTA, new BigDecimal("100.00"), null, PaymentMethod.TWINT));
        // Voto de 50 em Transferência bancária
        envelopes.add(new Envelope(3L, "Membro 3", EnvelopeType.VOTO, new BigDecimal("50.00"), null, PaymentMethod.TRANSFERENCIA));
        closing.setIdentifiedEntries(envelopes);

        // Oferta avulsa de 150 em Dinheiro
        closing.setUnidentifiedOfertaTotal(new BigDecimal("150.00"));
        closing.setUnidentifiedDinheiroTotal(new BigDecimal("150.00"));

        closing.calculateTotalsAndValidate();

        assertEquals(new BigDecimal("350.00"), closing.getTotalDinheiro());
        assertEquals(new BigDecimal("100.00"), closing.getTotalTwint());
        assertEquals(new BigDecimal("50.00"), closing.getTotalTransferencias());
        assertEquals(new BigDecimal("150.00"), closing.getTotalEletronico());
        assertEquals(new BigDecimal("500.00"), closing.getRegisteredTotal());
        assertEquals(new BigDecimal("350.00"), closing.getPhysicalTotal());
    }

    @Test
    public void testReconciliationFailsWhenPhysicalDiffersFromRegisteredCash() {
        ServiceClosing closing = new ServiceClosing();
        closing.setPhysicalTotal(new BigDecimal("300.00")); // Contou 300, mas registrou 350 em dinheiro

        List<Envelope> envelopes = new ArrayList<>();
        envelopes.add(new Envelope(1L, "Membro 1", EnvelopeType.DIZIMO, new BigDecimal("200.00"), null, PaymentMethod.DINHEIRO));
        envelopes.add(new Envelope(2L, "Membro 2", EnvelopeType.OFERTA, new BigDecimal("100.00"), null, PaymentMethod.TWINT));
        closing.setIdentifiedEntries(envelopes);

        closing.setUnidentifiedOfertaTotal(new BigDecimal("150.00"));
        closing.setUnidentifiedDinheiroTotal(new BigDecimal("150.00"));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () -> {
            closing.calculateTotalsAndValidate();
        });
        assertTrue(ex.getMessage().contains("dinheiro físico contado (CHF 300.00) difere do total de dinheiro registrado (CHF 350.00)"));
    }
}
