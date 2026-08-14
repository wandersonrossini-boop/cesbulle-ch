package com.tesourariacme.api.config;

import com.tesourariacme.api.domain.AppUser;
import com.tesourariacme.api.infrastructure.AppUserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

@Component
public class DataInitializer implements CommandLineRunner {

    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public DataInitializer(AppUserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        if (userRepository.count() == 0) {
            AppUser admin = new AppUser();
            admin.setUsername("pastor");
            admin.setName("Administrador do Sistema");
            admin.setPasswordHash(passwordEncoder.encode("Pr.124578.")); // Senha padrão inicial
            admin.setRole("ADMIN");
            admin.setAuthorized(true);
            userRepository.save(admin);
            System.out.println("Usuário ADMIN criado com sucesso: pastor / Pr.124578.");
        }
    }
}
