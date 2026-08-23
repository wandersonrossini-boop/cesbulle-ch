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
            return contributorRepository.searchActive(search.trim());
        }
        return contributorRepository.findAllByActiveTrue();
    }

    public Optional<Contributor> getById(Long id) {
        return contributorRepository.findById(id);
    }

    @Transactional
    public Contributor create(Contributor contributor) {
        if (contributor.getContributorNumber() == null || contributor.getContributorNumber().trim().isEmpty()) {
            throw new IllegalArgumentException("Número do contribuinte é obrigatório.");
        }
        if (contributorRepository.findByContributorNumber(contributor.getContributorNumber().trim()).isPresent()) {
            throw new IllegalArgumentException("Número do contribuinte já cadastrado.");
        }
        contributor.setContributorNumber(contributor.getContributorNumber().trim());
        return contributorRepository.save(contributor);
    }

    @Transactional
    public Contributor update(Long id, Contributor updated) {
        Contributor existing = contributorRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Contribuinte não encontrado."));

        if (updated.getContributorNumber() != null && !updated.getContributorNumber().trim().isEmpty()) {
            String newNum = updated.getContributorNumber().trim();
            if (!newNum.equalsIgnoreCase(existing.getContributorNumber())) {
                if (contributorRepository.findByContributorNumber(newNum).isPresent()) {
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

