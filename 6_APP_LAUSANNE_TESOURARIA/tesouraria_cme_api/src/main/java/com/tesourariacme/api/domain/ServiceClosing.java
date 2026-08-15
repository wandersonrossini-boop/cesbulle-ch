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

        if (physicalTotal.compareTo(registeredTotal) != 0) {
            throw new IllegalArgumentException("Fechamento inválido: total físico difere do total registrado.");
        }
    }
}
