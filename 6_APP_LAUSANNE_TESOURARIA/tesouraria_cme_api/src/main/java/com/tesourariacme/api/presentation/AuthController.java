package com.tesourariacme.api.presentation;

import com.tesourariacme.api.config.JwtUtil;
import lombok.Data;
import com.tesourariacme.api.domain.AppUser;
import com.tesourariacme.api.infrastructure.AppUserRepository;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")

public class AuthController {

    private static final org.slf4j.Logger logger = org.slf4j.LoggerFactory.getLogger(AuthController.class);

    private final JwtUtil jwtUtil;
    private final AuthenticationManager authenticationManager;
    private final AppUserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthController(JwtUtil jwtUtil, AuthenticationManager authenticationManager, AppUserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.jwtUtil = jwtUtil;
        this.authenticationManager = authenticationManager;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        if (request.getUsername() == null || request.getUsername().trim().isEmpty() ||
            request.getPassword() == null || request.getPassword().isEmpty()) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Credenciais inválidas.");
        }
        String normalizedUsername = request.getUsername().trim().toLowerCase();
        logger.info(">>> API RECEBEU TENTATIVA DE LOGIN. Username normalizado: '{}'", normalizedUsername);
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(normalizedUsername, request.getPassword())
            );

            // Se chegou aqui, as credenciais estão corretas e isAuthorized = true (ver CustomUserDetailsService)
            String token = jwtUtil.generateToken(normalizedUsername);
            logger.info(">>> LOGIN BEM-SUCEDIDO para '{}'", normalizedUsername);
            return ResponseEntity.ok(new LoginResponse(token));
        } catch (org.springframework.security.authentication.DisabledException e) {
            logger.error(">>> LOGIN FALHOU (DisabledException) para '{}': {}", normalizedUsername, e.getMessage());
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Usuário aguardando aprovação do Admin.");
        } catch (Exception e) {
            logger.error(">>> LOGIN FALHOU (Exception) para '{}': {}", normalizedUsername, e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body("Credenciais inválidas para o usuário: [" + normalizedUsername + "]");
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        if (request.getUsername() == null || request.getUsername().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("Nome de usuário é obrigatório.");
        }
        if (request.getName() == null || request.getName().trim().isEmpty()) {
            return ResponseEntity.badRequest().body("Nome completo é obrigatório.");
        }
        if (request.getPassword() == null || request.getPassword().trim().length() < 6) {
            return ResponseEntity.badRequest().body("A senha deve conter no mínimo 6 caracteres.");
        }

        String normalizedUsername = request.getUsername().trim().toLowerCase();
        if (userRepository.findByUsernameIgnoreCase(normalizedUsername).isPresent()) {
            return ResponseEntity.badRequest().body("Usuário já existe.");
        }

        AppUser newUser = new AppUser();
        newUser.setUsername(normalizedUsername);
        newUser.setName(request.getName().trim());
        newUser.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        newUser.setRole("TREASURER");
        newUser.setAuthorized(false); // Aguardando aprovação
        if (request.getAvatarBase64() != null) {
            newUser.setAvatarBase64(request.getAvatarBase64());
        }

        userRepository.save(newUser);
        return ResponseEntity.ok("Usuário cadastrado com sucesso. Aguardando aprovação.");
    }

    @GetMapping("/health")
    public ResponseEntity<?> health() {
        return ResponseEntity.ok(java.util.Map.of("status", "UP"));
    }
}

@Data
@lombok.NoArgsConstructor
@lombok.AllArgsConstructor
class LoginRequest {
    private String username;
    private String password;
}

@Data
class LoginResponse {
    private final String token;
}

@Data
@lombok.NoArgsConstructor
@lombok.AllArgsConstructor
class RegisterRequest {
    private String username;
    private String password;
    private String name;
    private String avatarBase64;
}
