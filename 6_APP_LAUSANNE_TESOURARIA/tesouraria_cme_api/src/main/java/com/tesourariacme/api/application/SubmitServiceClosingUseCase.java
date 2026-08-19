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
        
        // Verifier Validation
        if (serviceClosing.getVerifierName() == null || serviceClosing.getVerifierName().trim().isEmpty()) {
            throw new IllegalArgumentException("Nome do conferente não pode ser vazio.");
        } else {
            if (serviceClosing.getVerifierType() == null) {
                throw new IllegalArgumentException("Tipo de conferente deve ser informado se o nome for preenchido.");
            }
            if (serviceClosing.getVerifierType() == com.tesourariacme.api.domain.VerifierType.AUTHENTICATED) {
                throw new IllegalArgumentException("Tipo de conferente AUTHENTICATED não é suportado nesta fase.");
            }
            if (serviceClosing.getMainTreasurer() != null && serviceClosing.getVerifierName().trim().equalsIgnoreCase(serviceClosing.getMainTreasurer().trim())) {
                throw new IllegalArgumentException("O conferente deve ser uma pessoa diferente do responsável pela contagem.");
            }
        }

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
        return repository.findHistoryOrdered().stream().map(c -> {
            String vName = c.getVerifierName();
            String vType = c.getVerifierType() != null ? c.getVerifierType().name() : null;
            if (vName == null && c.getCoTreasurer() != null && !c.getCoTreasurer().trim().isEmpty()) {
                vName = c.getCoTreasurer();
                vType = "LEGACY";
            }
            return new com.tesourariacme.api.presentation.ServiceClosingSummaryResponse(
                c.getId(), c.getServiceDate(), c.getMainTreasurer(), c.getCoTreasurer(), vName, vType, c.getPhysicalTotal()
            );
        }).collect(java.util.stream.Collectors.toList());
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
