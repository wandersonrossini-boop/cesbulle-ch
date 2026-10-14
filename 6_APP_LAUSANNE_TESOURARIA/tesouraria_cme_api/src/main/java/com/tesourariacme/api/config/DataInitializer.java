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

    @org.springframework.beans.factory.annotation.Value("${admin.initial-password:Pr.124578.}")
    private String initialAdminPassword;

    @Override
    public void run(String... args) {
        if (userRepository.findByUsername("pastor").isEmpty()) {
            AppUser admin = userRepository.findByUsername("admin").orElse(new AppUser());
            admin.setUsername("pastor");
            admin.setName("Administrador do Sistema");
            admin.setPasswordHash(passwordEncoder.encode(initialAdminPassword));
            admin.setRole("ADMIN");
            admin.setAuthorized(true);
            userRepository.save(admin);
            logger.info(">>> Configured default admin user.");
        } else {
            logger.info(">>> Admin user 'pastor' already exists. Preserving existing credentials.");
        }
    }
}
