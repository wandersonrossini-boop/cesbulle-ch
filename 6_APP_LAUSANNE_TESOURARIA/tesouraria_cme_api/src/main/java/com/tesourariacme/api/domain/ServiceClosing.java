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
public class ServiceClosing {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private LocalDate serviceDate;
    private String mainTreasurer; // "Admilson"
    private String coTreasurer;
    private String verifierName;

    @Enumerated(EnumType.STRING)
    private VerifierType verifierType;

    @OneToMany(cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Envelope> identifiedEntries = new ArrayList<>();

    private BigDecimal physicalTotal;
    private BigDecimal unidentifiedDizimoTotal;
    private BigDecimal unidentifiedOfertaTotal;
    private BigDecimal unidentifiedVotoTotal;
    
    // Dimensões de Meios de Recebimento
    private BigDecimal unidentifiedDinheiroTotal;
    private BigDecimal unidentifiedTwintTotal;
    private BigDecimal unidentifiedTransferenciaTotal;

    private BigDecimal totalDinheiro;
    private BigDecimal totalEletronico;
    private BigDecimal totalTwint;
    private BigDecimal totalTransferencias;

    private BigDecimal unidentifiedTotal;
    private BigDecimal identifiedTotal;
    private BigDecimal registeredTotal;

    private BigDecimal totalDizimos;
    private BigDecimal totalOfertas;
    private BigDecimal totalVotos;

    public void calculateTotalsAndValidate() {
        if (physicalTotal == null) physicalTotal = BigDecimal.ZERO;
        if (unidentifiedDizimoTotal == null) unidentifiedDizimoTotal = BigDecimal.ZERO;
        if (unidentifiedOfertaTotal == null) unidentifiedOfertaTotal = BigDecimal.ZERO;
        if (unidentifiedVotoTotal == null) unidentifiedVotoTotal = BigDecimal.ZERO;
        
        if (unidentifiedDinheiroTotal == null) unidentifiedDinheiroTotal = BigDecimal.ZERO;
        if (unidentifiedTwintTotal == null) unidentifiedTwintTotal = BigDecimal.ZERO;
        if (unidentifiedTransferenciaTotal == null) unidentifiedTransferenciaTotal = BigDecimal.ZERO;

        identifiedTotal = identifiedEntries.stream()
                .map(Envelope::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        unidentifiedTotal = unidentifiedDizimoTotal.add(unidentifiedOfertaTotal).add(unidentifiedVotoTotal);
        registeredTotal = identifiedTotal.add(unidentifiedTotal);

        totalDizimos = identifiedEntries.stream()
                .filter(e -> e.getType() == EnvelopeType.DIZIMO)
                .map(Envelope::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .add(unidentifiedDizimoTotal);

        totalOfertas = identifiedEntries.stream()
                .filter(e -> e.getType() == EnvelopeType.OFERTA)
                .map(Envelope::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .add(unidentifiedOfertaTotal);

        totalVotos = identifiedEntries.stream()
                .filter(e -> e.getType() == EnvelopeType.VOTO)
                .map(Envelope::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add)
                .add(unidentifiedVotoTotal);

        // Separação por meio de recebimento
        BigDecimal identifiedDinheiro = identifiedEntries.stream()
                .filter(e -> e.getPaymentMethod() == null || e.getPaymentMethod() == PaymentMethod.DINHEIRO)
                .map(Envelope::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal identifiedTwint = identifiedEntries.stream()
                .filter(e -> e.getPaymentMethod() == PaymentMethod.TWINT)
                .map(Envelope::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal identifiedTransferencia = identifiedEntries.stream()
                .filter(e -> e.getPaymentMethod() == PaymentMethod.TRANSFERENCIA)
                .map(Envelope::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal unidentifiedElectronicSum = unidentifiedTwintTotal.add(unidentifiedTransferenciaTotal);
        BigDecimal effectiveUnidentifiedDinheiro;

        if (unidentifiedDinheiroTotal.compareTo(BigDecimal.ZERO) > 0 || unidentifiedElectronicSum.compareTo(BigDecimal.ZERO) > 0) {
            effectiveUnidentifiedDinheiro = unidentifiedDinheiroTotal;
        } else {
            // Compatibilidade regressiva: se não discriminou meios anônimos, assume dinheiro
            effectiveUnidentifiedDinheiro = unidentifiedTotal;
        }

        totalDinheiro = identifiedDinheiro.add(effectiveUnidentifiedDinheiro);
        totalTwint = identifiedTwint.add(unidentifiedTwintTotal);
        totalTransferencias = identifiedTransferencia.add(unidentifiedTransferenciaTotal);
        totalEletronico = totalTwint.add(totalTransferencias);

        // Regra contábil de reconciliação física:
        // O dinheiro físico contado na mesa (physicalTotal) deve conferir com o total recebido em dinheiro (totalDinheiro).
        if (physicalTotal.compareTo(totalDinheiro) != 0) {
            throw new IllegalArgumentException(String.format(
                    "Fechamento inválido: dinheiro físico contado (CHF %s) difere do total de dinheiro registrado (CHF %s).",
                    physicalTotal, totalDinheiro));
        }
    }
}
