package com.tesourariacme.api.domain;

import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.infrastructure.MemberRepository;

public class ServiceClosingTest {

    @Test
    public void testCalculateTotalsAndValidate_AcceptsWhenDifferenceIsZero() {
        ServiceClosing closing = new ServiceClosing();
        
        // Identificado 190
        closing.setIdentifiedEntries(List.of(
            new Envelope(null, "João", EnvelopeType.DIZIMO, new BigDecimal("100")),
            new Envelope(null, "Maria", EnvelopeType.OFERTA, new BigDecimal("90"))
        ));
        
        // Não identificado 60
        closing.setUnidentifiedDizimoTotal(new BigDecimal("20"));
        closing.setUnidentifiedOfertaTotal(new BigDecimal("30"));
        closing.setUnidentifiedVotoTotal(new BigDecimal("10"));
        
        // Físico 250
        closing.setPhysicalTotal(new BigDecimal("250"));
        
        // → ACEITA
        assertDoesNotThrow(() -> closing.calculateTotalsAndValidate());
        
        assertEquals(0, new BigDecimal("190").compareTo(closing.getIdentifiedTotal()));
        assertEquals(0, new BigDecimal("60").compareTo(closing.getUnidentifiedTotal()));
        assertEquals(0, new BigDecimal("250").compareTo(closing.getRegisteredTotal()));
    }

    @Test
    public void testCalculateTotalsAndValidate_RejectsWhenDifferenceIsNonZero() {
        ServiceClosing closing = new ServiceClosing();
        
        // Identificado 190
        closing.setIdentifiedEntries(List.of(
            new Envelope(null, "João", EnvelopeType.DIZIMO, new BigDecimal("100")),
            new Envelope(null, "Maria", EnvelopeType.OFERTA, new BigDecimal("90"))
        ));
        
        // Não identificado 50
        closing.setUnidentifiedDizimoTotal(new BigDecimal("20"));
        closing.setUnidentifiedOfertaTotal(new BigDecimal("20"));
        closing.setUnidentifiedVotoTotal(new BigDecimal("10"));
        
        // Físico 250
        closing.setPhysicalTotal(new BigDecimal("250"));
        
        // → REJEITA (diferença 10)
        IllegalArgumentException thrown = assertThrows(IllegalArgumentException.class, () -> {
            closing.calculateTotalsAndValidate();
        });
        assertEquals("Fechamento inválido: total físico difere do total registrado.", thrown.getMessage());
    }

    @Test
    public void testCalculateTotalsAndValidate_SumsUnidentifiedCorrectly() {
        ServiceClosing closing = new ServiceClosing();
        
        // Dízimo não identificado 20
        closing.setUnidentifiedDizimoTotal(new BigDecimal("20"));
        // Oferta não identificada 30
        closing.setUnidentifiedOfertaTotal(new BigDecimal("30"));
        // Voto não identificado 10
        closing.setUnidentifiedVotoTotal(new BigDecimal("10"));
        
        closing.setPhysicalTotal(new BigDecimal("60"));
        
        closing.calculateTotalsAndValidate();
        
        // → unidentifiedTotal = 60
        assertEquals(0, new BigDecimal("60").compareTo(closing.getUnidentifiedTotal()));
    }

    @Test
    public void testSubmitValidation() {
        ServiceClosingRepository repo = org.mockito.Mockito.mock(ServiceClosingRepository.class);
        MemberRepository memberRepo = org.mockito.Mockito.mock(MemberRepository.class);
        com.tesourariacme.api.application.SubmitServiceClosingUseCase useCase = 
            new com.tesourariacme.api.application.SubmitServiceClosingUseCase(repo, memberRepo);

        // Case 1: SELECTED + nome -> aceito
        ServiceClosing c1 = new ServiceClosing();
        c1.setPhysicalTotal(BigDecimal.ZERO);
        c1.setVerifierType(VerifierType.SELECTED);
        c1.setVerifierName("Admilson");
        assertDoesNotThrow(() -> useCase.execute(c1));

        // Case 2: MANUAL + nome -> aceito
        ServiceClosing c2 = new ServiceClosing();
        c2.setPhysicalTotal(BigDecimal.ZERO);
        c2.setVerifierType(VerifierType.MANUAL);
        c2.setVerifierName("Pastor Joao");
        assertDoesNotThrow(() -> useCase.execute(c2));

        // Case 3: SELECTED + nome vazio -> rejeitado
        ServiceClosing c3 = new ServiceClosing();
        c3.setPhysicalTotal(BigDecimal.ZERO);
        c3.setVerifierType(VerifierType.SELECTED);
        c3.setVerifierName("");
        IllegalArgumentException ex3 = assertThrows(IllegalArgumentException.class, () -> useCase.execute(c3));
        assertTrue(ex3.getMessage().contains("Nome do conferente não pode ser vazio"));

        // Case 4: MANUAL + nome vazio -> rejeitado
        ServiceClosing c4 = new ServiceClosing();
        c4.setPhysicalTotal(BigDecimal.ZERO);
        c4.setVerifierType(VerifierType.MANUAL);
        c4.setVerifierName(null);
        IllegalArgumentException ex4 = assertThrows(IllegalArgumentException.class, () -> useCase.execute(c4));
        assertTrue(ex4.getMessage().contains("Nome do conferente não pode ser vazio"));

        // Case 5: nome informado + tipo ausente -> rejeitado
        ServiceClosing c5 = new ServiceClosing();
        c5.setPhysicalTotal(BigDecimal.ZERO);
        c5.setVerifierType(null);
        c5.setVerifierName("Pastor Joao");
        IllegalArgumentException ex5 = assertThrows(IllegalArgumentException.class, () -> useCase.execute(c5));
        assertTrue(ex5.getMessage().contains("Tipo de conferente deve ser informado se o nome for preenchido"));

        // Case 6: payload legado somente com coTreasurer -> aceito
        ServiceClosing c6 = new ServiceClosing();
        c6.setPhysicalTotal(BigDecimal.ZERO);
        c6.setVerifierType(null);
        c6.setVerifierName(null);
        c6.setCoTreasurer("Wan");
        assertDoesNotThrow(() -> useCase.execute(c6));

        // Case 7: AUTHENTICATED -> rejeitado nesta fase
        ServiceClosing c7 = new ServiceClosing();
        c7.setPhysicalTotal(BigDecimal.ZERO);
        c7.setVerifierType(VerifierType.AUTHENTICATED);
        c7.setVerifierName("Admilson");
        IllegalArgumentException ex7 = assertThrows(IllegalArgumentException.class, () -> useCase.execute(c7));
        assertTrue(ex7.getMessage().contains("Tipo de conferente AUTHENTICATED não é suportado nesta fase"));
    }
}
