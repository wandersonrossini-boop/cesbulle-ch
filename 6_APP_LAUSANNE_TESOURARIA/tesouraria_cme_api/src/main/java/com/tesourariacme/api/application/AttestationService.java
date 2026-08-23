package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.Contributor;
import com.tesourariacme.api.domain.Envelope;
import com.tesourariacme.api.domain.EnvelopeType;
import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.infrastructure.ContributorRepository;
import com.tesourariacme.api.infrastructure.EnvelopeRepository;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.presentation.AnnualSummaryDTO;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Service
public class AttestationService {

    private final ContributorRepository contributorRepository;
    private final EnvelopeRepository envelopeRepository;
    private final ServiceClosingRepository serviceClosingRepository;

    public AttestationService(
            ContributorRepository contributorRepository,
            EnvelopeRepository envelopeRepository,
            ServiceClosingRepository serviceClosingRepository) {
        this.contributorRepository = contributorRepository;
        this.envelopeRepository = envelopeRepository;
        this.serviceClosingRepository = serviceClosingRepository;
    }

    public AnnualSummaryDTO generateAnnualSummary(Long contributorId, int year) {
        Contributor contributor = contributorRepository.findById(contributorId)
                .orElseThrow(() -> new IllegalArgumentException("Contribuinte não encontrado."));

        LocalDate startDate = LocalDate.of(year, 1, 1);
        LocalDate endDate = LocalDate.of(year, 12, 31);

        List<ServiceClosing> closings = serviceClosingRepository.findByServiceDateBetween(startDate, endDate);

        List<AnnualSummaryDTO.EntryDetail> details = new ArrayList<>();
        BigDecimal totalTithes = BigDecimal.ZERO;
        BigDecimal totalVows = BigDecimal.ZERO;

        for (ServiceClosing sc : closings) {
            if (sc.getIdentifiedEntries() != null) {
                for (Envelope env : sc.getIdentifiedEntries()) {
                    if (contributorId.equals(env.getContributorId())) {
                        BigDecimal amt = env.getAmount() != null ? env.getAmount() : BigDecimal.ZERO;
                        
                        AnnualSummaryDTO.EntryDetail detail = new AnnualSummaryDTO.EntryDetail(
                                sc.getServiceDate(),
                                env.getType() != null ? env.getType().name() : "OUTRO",
                                amt
                        );
                        details.add(detail);

                        if (env.getType() == EnvelopeType.DIZIMO) {
                            totalTithes = totalTithes.add(amt);
                        } else if (env.getType() == EnvelopeType.VOTO) {
                            totalVows = totalVows.add(amt);
                        }
                    }
                }
            }
        }

        BigDecimal totalConsolidated = totalTithes.add(totalVows);

        return new AnnualSummaryDTO(
                contributor.getId(),
                contributor.getFullName(),
                contributor.getContributorNumber(),
                contributor.getAddress(),
                contributor.getPostalCode(),
                contributor.getCity(),
                year,
                totalTithes,
                totalVows,
                totalConsolidated,
                details
        );
    }

    public byte[] generateAttestationPdf(Long contributorId, int year) {
        AnnualSummaryDTO summary = generateAnnualSummary(contributorId, year);

        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
        
        com.lowagie.text.Document document = new com.lowagie.text.Document(com.lowagie.text.PageSize.A4, 50, 50, 50, 50);
        try {
            com.lowagie.text.pdf.PdfWriter.getInstance(document, out);
            document.open();

            // Font Styles
            com.lowagie.text.Font titleFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA_BOLD, 18);
            com.lowagie.text.Font subTitleFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA_BOLD, 12);
            com.lowagie.text.Font bodyFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA, 10);
            com.lowagie.text.Font boldFont = com.lowagie.text.FontFactory.getFont(com.lowagie.text.FontFactory.HELVETICA_BOLD, 10);

            // 1. Institution Header
            com.lowagie.text.Paragraph header = new com.lowagie.text.Paragraph();
            header.add(new com.lowagie.text.Paragraph("CENTRE MISSIONNAIRE EVANGELIQUE (CME) - LAUSANNE", subTitleFont));
            header.add(new com.lowagie.text.Paragraph("Chemin de la Colline 7, 1007 Lausanne\nAssociation religieuse exoneree d'impots", bodyFont));
            header.setSpacingAfter(40);
            document.add(header);

            // 2. Member Address Box (Right aligned)
            com.lowagie.text.Paragraph addressBox = new com.lowagie.text.Paragraph();
            addressBox.setAlignment(com.lowagie.text.Element.ALIGN_RIGHT);
            addressBox.add(new com.lowagie.text.Paragraph(summary.getFullName(), boldFont));
            if (summary.getAddress() != null) addressBox.add(new com.lowagie.text.Paragraph(summary.getAddress(), bodyFont));
            String cityLine = (summary.getPostalCode() != null ? summary.getPostalCode() : "") + " " + (summary.getCity() != null ? summary.getCity() : "");
            if (!cityLine.trim().isEmpty()) addressBox.add(new com.lowagie.text.Paragraph(cityLine, bodyFont));
            addressBox.setSpacingAfter(40);
            document.add(addressBox);

            // 3. Title
            com.lowagie.text.Paragraph title = new com.lowagie.text.Paragraph("ATTESTATION DE DONS - ANNEE FISCALE " + year, titleFont);
            title.setAlignment(com.lowagie.text.Element.ALIGN_CENTER);
            title.setSpacingAfter(24);
            document.add(title);

            // 4. Body Paragraph
            String bodyText = String.format(
                    "Nous certifions par la presente que M./Mme %s (N° Contribuable: %s) a verse au Centre Missionnaire " +
                    "Evangelique Lausanne, pour la periode du 01.01.%d au 31.12.%d, la somme de:\n\n",
                    summary.getFullName(), summary.getContributorNumber(), year, year
            );
            com.lowagie.text.Paragraph body = new com.lowagie.text.Paragraph(bodyText, bodyFont);
            document.add(body);

            // Highlight box
            com.lowagie.text.Paragraph totalBox = new com.lowagie.text.Paragraph(
                    String.format("Montant Total: CHF %s\n(Dimes: CHF %s | Voeux & Missions: CHF %s)",
                            summary.getTotalConsolidated().toString(),
                            summary.getTotalTithes().toString(),
                            summary.getTotalVows().toString()),
                    boldFont
            );
            totalBox.setAlignment(com.lowagie.text.Element.ALIGN_CENTER);
            totalBox.setSpacingAfter(30);
            document.add(totalBox);

            // 5. Table of Details
            if (summary.getDetails() != null && !summary.getDetails().isEmpty()) {
                com.lowagie.text.pdf.PdfPTable table = new com.lowagie.text.pdf.PdfPTable(3);
                table.setWidthPercentage(100);
                table.setWidths(new float[]{1.5f, 2.0f, 1.5f});
                table.setSpacingBefore(10);
                table.setSpacingAfter(30);

                table.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("DATE", boldFont)));
                table.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("TYPE DE DON", boldFont)));
                table.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("MONTANT", boldFont)));

                for (AnnualSummaryDTO.EntryDetail detail : summary.getDetails()) {
                    table.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(detail.getDate().toString(), bodyFont)));
                    table.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph(detail.getType(), bodyFont)));
                    table.addCell(new com.lowagie.text.pdf.PdfPCell(new com.lowagie.text.Paragraph("CHF " + detail.getAmount().toString(), bodyFont)));
                }
                document.add(table);
            }

            // 6. Sign-off
            com.lowagie.text.Paragraph signOff = new com.lowagie.text.Paragraph();
            signOff.add(new com.lowagie.text.Paragraph("Fait a Lausanne, le " + LocalDate.now().toString(), bodyFont));
            signOff.add(new com.lowagie.text.Paragraph("\n\nLe Service de la Tresorerie\nCME Lausanne", boldFont));
            signOff.setSpacingBefore(20);
            document.add(signOff);

            document.close();
        } catch (Exception e) {
            throw new RuntimeException("Erreur de generation PDF: " + e.getMessage(), e);
        }

        return out.toByteArray();
    }
}
