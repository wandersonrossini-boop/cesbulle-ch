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

        if (physicalTotal.compareTo(registeredTotal) != 0) {
            throw new IllegalArgumentException("Fechamento inválido: total físico difere do total registrado.");
        }
    }
}
