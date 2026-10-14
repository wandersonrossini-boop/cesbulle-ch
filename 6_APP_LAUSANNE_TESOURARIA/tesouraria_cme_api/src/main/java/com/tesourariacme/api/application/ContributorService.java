package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.Contributor;
import com.tesourariacme.api.infrastructure.ContributorRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
public class ContributorService {

    private final ContributorRepository contributorRepository;

    private final com.tesourariacme.api.infrastructure.EnvelopeRepository envelopeRepository;

    public ContributorService(ContributorRepository contributorRepository, com.tesourariacme.api.infrastructure.EnvelopeRepository envelopeRepository) {
        this.envelopeRepository = envelopeRepository;
        this.contributorRepository = contributorRepository;
    }

    public List<Contributor> getAll(String search) {
        if (search != null && !search.trim().isEmpty()) {
            return contributorRepository.findAll().stream()
                .filter(c -> c.getFullName().toLowerCase().contains(search.trim().toLowerCase()) ||
                             c.getContributorNumber().toLowerCase().contains(search.trim().toLowerCase()))
                .sorted((a, b) -> a.getFullName().compareToIgnoreCase(b.getFullName()))
                .toList();
        }
        return contributorRepository.findAll().stream()
            .sorted((a, b) -> a.getFullName().compareToIgnoreCase(b.getFullName()))
            .toList();
    }

    public Optional<Contributor> getById(Long id) {
        return contributorRepository.findById(id);
    }

    public synchronized String generateUniqueContributorNumber() {
        List<Contributor> all = contributorRepository.findAll();
        int maxSeq = 0;
        java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("^(?:LS-|CONT-|CH-LS-)?(\\d+)$", java.util.regex.Pattern.CASE_INSENSITIVE);
        for (Contributor c : all) {
            if (c.getContributorNumber() != null) {
                java.util.regex.Matcher m = pattern.matcher(c.getContributorNumber().trim());
                if (m.matches()) {
                    try {
                        int val = Integer.parseInt(m.group(1));
                        if (val > maxSeq) {
                            maxSeq = val;
                        }
                    } catch (NumberFormatException ignored) {}
                }
            }
        }
        int next = maxSeq + 1;
        String candidate = String.format("LS-%03d", next);
        while (contributorRepository.findByContributorNumberIgnoreCase(candidate).isPresent()) {
            next++;
            candidate = String.format("LS-%03d", next);
        }
        return candidate;
    }

    @Transactional
    public Contributor create(Contributor contributor) {
        if (contributor.getFullName() == null || contributor.getFullName().trim().isEmpty()) {
            throw new IllegalArgumentException("Nome completo é obrigatório.");
        }
        contributor.setFullName(contributor.getFullName().trim());

        if (contributor.getContributorNumber() == null || contributor.getContributorNumber().trim().isEmpty()) {
            contributor.setContributorNumber(generateUniqueContributorNumber());
        } else {
            String num = contributor.getContributorNumber().trim();
            if (contributorRepository.findByContributorNumberIgnoreCase(num).isPresent()) {
                throw new IllegalArgumentException("Número do contribuinte já cadastrado.");
            }
            contributor.setContributorNumber(num);
        }
        return contributorRepository.save(contributor);
    }

    @Transactional
    public Contributor update(Long id, Contributor updated) {
        Contributor existing = contributorRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Contribuinte não encontrado."));

        if (updated.getFullName() != null && !updated.getFullName().trim().isEmpty()) {
            existing.setFullName(updated.getFullName().trim());
        }

        if (updated.getContributorNumber() != null && !updated.getContributorNumber().trim().isEmpty()) {
            String newNum = updated.getContributorNumber().trim();
            if (!newNum.equalsIgnoreCase(existing.getContributorNumber())) {
                if (contributorRepository.findByContributorNumberIgnoreCase(newNum).isPresent()) {
                    throw new IllegalArgumentException("Número do contribuinte já cadastrado.");
                }
                existing.setContributorNumber(newNum);
            }
        }

        existing.setFullName(updated.getFullName());
        existing.setAddress(updated.getAddress());
        existing.setPostalCode(updated.getPostalCode());
        existing.setCity(updated.getCity());
        existing.setEmail(updated.getEmail());
        existing.setPhone(updated.getPhone());
        existing.setActive(updated.isActive());

        return contributorRepository.save(existing);
    }

    @Transactional
    public void delete(Long id) {
        Contributor existing = contributorRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Contribuinte não encontrado."));
        
        long envelopeCount = envelopeRepository.countByContributorId(id);
        if (envelopeCount == 0) {
            contributorRepository.delete(existing);
        } else {
            existing.setActive(false);
            contributorRepository.save(existing);
        }
    }
}

