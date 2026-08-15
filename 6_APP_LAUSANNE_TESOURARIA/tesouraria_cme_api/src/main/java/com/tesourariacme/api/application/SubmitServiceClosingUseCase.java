package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.ServiceClosing;
import com.tesourariacme.api.domain.Member;
import com.tesourariacme.api.infrastructure.ServiceClosingRepository;
import com.tesourariacme.api.infrastructure.MemberRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SubmitServiceClosingUseCase {

    private final ServiceClosingRepository repository;
    private final MemberRepository memberRepository;

    public SubmitServiceClosingUseCase(ServiceClosingRepository repository, MemberRepository memberRepository) {
        this.repository = repository;
        this.memberRepository = memberRepository;
    }

    @Transactional
    public ServiceClosing execute(ServiceClosing serviceClosing) {
        serviceClosing.calculateTotalsAndValidate();
        
        // Passive Member Registration
        if (serviceClosing.getIdentifiedEntries() != null) {
            serviceClosing.getIdentifiedEntries().forEach(env -> {
                String name = env.getMemberName();
                if (name != null && !name.trim().isEmpty()) {
                    memberRepository.findByNameIgnoreCase(name.trim()).orElseGet(() -> {
                        return memberRepository.save(new Member(name.trim()));
                    });
                }
            });
        }
        
        return repository.save(serviceClosing);
    }

    public java.util.List<com.tesourariacme.api.presentation.ServiceClosingSummaryResponse> getHistory() {
        return repository.findHistoryOrdered().stream().map(c ->
            new com.tesourariacme.api.presentation.ServiceClosingSummaryResponse(
                c.getId(), c.getServiceDate(), c.getMainTreasurer(), c.getCoTreasurer(), c.getPhysicalTotal()
            )
        ).collect(java.util.stream.Collectors.toList());
    }

    public ServiceClosing getById(Long id) {
        return repository.findById(id).orElseThrow(() -> new IllegalArgumentException("Fechamento não encontrado"));
    }

    @Transactional
    public void deleteById(Long id) {
        if (!repository.existsById(id)) {
            throw new IllegalArgumentException("Fechamento não encontrado");
        }
        repository.deleteById(id);
    }
}
