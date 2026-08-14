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

    private static final org.slf4j.Logger logger = org.slf4j.LoggerFactory.getLogger(DataInitializer.class);

    @Override
    public void run(String... args) {
        if (userRepository.findByUsername("pastor").isEmpty()) {
            AppUser admin = userRepository.findByUsername("admin").orElse(new AppUser());
            admin.setUsername("pastor");
            admin.setName("Administrador do Sistema");
            admin.setPasswordHash(passwordEncoder.encode("Pr.124578."));
            admin.setRole("ADMIN");
            admin.setAuthorized(true);
            userRepository.save(admin);
            logger.info(">>> Usuário ADMIN (pastor) verificado/criado com sucesso!");
        } else {
            // Atualizar a senha do pastor caso já exista, para garantir o acesso neste momento
            AppUser pastor = userRepository.findByUsername("pastor").get();
            pastor.setPasswordHash(passwordEncoder.encode("Pr.124578."));
            pastor.setAuthorized(true);
            pastor.setRole("ADMIN");
            userRepository.save(pastor);
            logger.info(">>> Usuário ADMIN (pastor) atualizado com sucesso!");
        }

        // Print existing users for debugging
        userRepository.findAll().forEach(user -> {
            logger.info(">>> USER IN DB: username={}, role={}, isAuthorized={}", 
                user.getUsername(), user.getRole(), user.isAuthorized());
        });
    }
}
