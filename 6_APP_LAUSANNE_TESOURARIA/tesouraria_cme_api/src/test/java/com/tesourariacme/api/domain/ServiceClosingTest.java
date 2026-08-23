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
        com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService = org.mockito.Mockito.mock(com.tesourariacme.api.application.MonthlyPeriodService.class);
        org.mockito.Mockito.when(monthlyPeriodService.isPeriodLocked(org.mockito.ArgumentMatchers.any(java.time.LocalDate.class))).thenReturn(false);
        com.tesourariacme.api.application.AuditLogService auditLogService = org.mockito.Mockito.mock(com.tesourariacme.api.application.AuditLogService.class);
        com.tesourariacme.api.application.SubmitServiceClosingUseCase useCase = 
            new com.tesourariacme.api.application.SubmitServiceClosingUseCase(repo, memberRepo, monthlyPeriodService, auditLogService);

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

        // Case 6: payload legado somente com coTreasurer -> rejeitado na nova submissão
        ServiceClosing c6 = new ServiceClosing();
        c6.setPhysicalTotal(BigDecimal.ZERO);
        c6.setVerifierType(null);
        c6.setVerifierName(null);
        c6.setCoTreasurer("Wan");
        IllegalArgumentException ex6 = assertThrows(IllegalArgumentException.class, () -> useCase.execute(c6));
        assertTrue(ex6.getMessage().contains("Nome do conferente não pode ser vazio"));

        // Case 7: AUTHENTICATED -> rejeitado nesta fase
        ServiceClosing c7 = new ServiceClosing();
        c7.setPhysicalTotal(BigDecimal.ZERO);
        c7.setVerifierType(VerifierType.AUTHENTICATED);
        c7.setVerifierName("Admilson");
        IllegalArgumentException ex7 = assertThrows(IllegalArgumentException.class, () -> useCase.execute(c7));
        assertTrue(ex7.getMessage().contains("Tipo de conferente AUTHENTICATED não é suportado nesta fase"));
    }

    @Test
    public void testDoubleVerificationScenarios() {
        ServiceClosingRepository repo = org.mockito.Mockito.mock(ServiceClosingRepository.class);
        MemberRepository memberRepo = org.mockito.Mockito.mock(MemberRepository.class);
        com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService = org.mockito.Mockito.mock(com.tesourariacme.api.application.MonthlyPeriodService.class);
        org.mockito.Mockito.when(monthlyPeriodService.isPeriodLocked(org.mockito.ArgumentMatchers.any(java.time.LocalDate.class))).thenReturn(false);
        com.tesourariacme.api.application.AuditLogService auditLogService = org.mockito.Mockito.mock(com.tesourariacme.api.application.AuditLogService.class);
        com.tesourariacme.api.application.SubmitServiceClosingUseCase useCase = 
            new com.tesourariacme.api.application.SubmitServiceClosingUseCase(repo, memberRepo, monthlyPeriodService, auditLogService);

        // Cenário A: mainTreasurer = "Anderson", verifierName = "Anderson" -> REJEITADO
        ServiceClosing cA = new ServiceClosing();
        cA.setPhysicalTotal(BigDecimal.ZERO);
        cA.setVerifierType(VerifierType.MANUAL);
        cA.setMainTreasurer("Anderson");
        cA.setVerifierName("Anderson");
        IllegalArgumentException exA = assertThrows(IllegalArgumentException.class, () -> useCase.execute(cA));
        assertTrue(exA.getMessage().contains("O conferente deve ser uma pessoa diferente"));

        // Cenário B: mainTreasurer = "Anderson", verifierName = " anderson " -> REJEITADO
        ServiceClosing cB = new ServiceClosing();
        cB.setPhysicalTotal(BigDecimal.ZERO);
        cB.setVerifierType(VerifierType.MANUAL);
        cB.setMainTreasurer("Anderson");
        cB.setVerifierName(" anderson ");
        IllegalArgumentException exB = assertThrows(IllegalArgumentException.class, () -> useCase.execute(cB));
        assertTrue(exB.getMessage().contains("O conferente deve ser uma pessoa diferente"));

        // Cenário C: mainTreasurer = "Anderson", coTreasurer = "Maria", verifierName = "Maria" -> ACEITO
        ServiceClosing cC = new ServiceClosing();
        cC.setPhysicalTotal(BigDecimal.ZERO);
        cC.setVerifierType(VerifierType.MANUAL);
        cC.setMainTreasurer("Anderson");
        cC.setCoTreasurer("Maria");
        cC.setVerifierName("Maria");
        assertDoesNotThrow(() -> useCase.execute(cC));

        // Cenário D: mainTreasurer = "Anderson", verifierName = "João" -> ACEITO
        ServiceClosing cD = new ServiceClosing();
        cD.setPhysicalTotal(BigDecimal.ZERO);
        cD.setVerifierType(VerifierType.MANUAL);
        cD.setMainTreasurer("Anderson");
        cD.setVerifierName("João");
        assertDoesNotThrow(() -> useCase.execute(cD));
    }

    @Test
    public void testGateT4ScenariosAF() {
        ServiceClosingRepository repo = org.mockito.Mockito.mock(ServiceClosingRepository.class);
        MemberRepository memberRepo = org.mockito.Mockito.mock(MemberRepository.class);
        com.tesourariacme.api.application.MonthlyPeriodService monthlyPeriodService = org.mockito.Mockito.mock(com.tesourariacme.api.application.MonthlyPeriodService.class);
        org.mockito.Mockito.when(monthlyPeriodService.isPeriodLocked(org.mockito.ArgumentMatchers.any(java.time.LocalDate.class))).thenReturn(false);
        com.tesourariacme.api.application.AuditLogService auditLogService = org.mockito.Mockito.mock(com.tesourariacme.api.application.AuditLogService.class);
        com.tesourariacme.api.application.SubmitServiceClosingUseCase useCase = 
            new com.tesourariacme.api.application.SubmitServiceClosingUseCase(repo, memberRepo, monthlyPeriodService, auditLogService);

        // Cenário A: main="A", verifier=null, co="B" -> REJEITADO
        ServiceClosing cA = new ServiceClosing();
        cA.setPhysicalTotal(BigDecimal.ZERO);
        cA.setMainTreasurer("A");
        cA.setVerifierName(null);
        cA.setCoTreasurer("B");
        IllegalArgumentException exA = assertThrows(IllegalArgumentException.class, () -> useCase.execute(cA));
        assertTrue(exA.getMessage().contains("Nome do conferente não pode ser vazio"));

        // Cenário B: main="A", verifier="", co="B" -> REJEITADO
        ServiceClosing cB = new ServiceClosing();
        cB.setPhysicalTotal(BigDecimal.ZERO);
        cB.setMainTreasurer("A");
        cB.setVerifierName("");
        cB.setCoTreasurer("B");
        IllegalArgumentException exB = assertThrows(IllegalArgumentException.class, () -> useCase.execute(cB));
        assertTrue(exB.getMessage().contains("Nome do conferente não pode ser vazio"));

        // Cenário C: main="A", verifier="A" -> REJEITADO
        ServiceClosing cC = new ServiceClosing();
        cC.setPhysicalTotal(BigDecimal.ZERO);
        cC.setMainTreasurer("A");
        cC.setVerifierName("A");
        cC.setVerifierType(VerifierType.MANUAL);
        IllegalArgumentException exC = assertThrows(IllegalArgumentException.class, () -> useCase.execute(cC));
        assertTrue(exC.getMessage().contains("O conferente deve ser uma pessoa diferente"));

        // Cenário D: main="A", verifier=" a " -> REJEITADO
        ServiceClosing cD = new ServiceClosing();
        cD.setPhysicalTotal(BigDecimal.ZERO);
        cD.setMainTreasurer("A");
        cD.setVerifierName(" a ");
        cD.setVerifierType(VerifierType.MANUAL);
        IllegalArgumentException exD = assertThrows(IllegalArgumentException.class, () -> useCase.execute(cD));
        assertTrue(exD.getMessage().contains("O conferente deve ser uma pessoa diferente"));

        // Cenário E: main="A", co="B", verifier="B" -> ACEITO
        ServiceClosing cE = new ServiceClosing();
        cE.setPhysicalTotal(BigDecimal.ZERO);
        cE.setMainTreasurer("A");
        cE.setCoTreasurer("B");
        cE.setVerifierName("B");
        cE.setVerifierType(VerifierType.MANUAL);
        assertDoesNotThrow(() -> useCase.execute(cE));

        // Cenário F: main="A", verifier="C" -> ACEITO
        ServiceClosing cF = new ServiceClosing();
        cF.setPhysicalTotal(BigDecimal.ZERO);
        cF.setMainTreasurer("A");
        cF.setVerifierName("C");
        cF.setVerifierType(VerifierType.MANUAL);
        assertDoesNotThrow(() -> useCase.execute(cF));
    }
}
