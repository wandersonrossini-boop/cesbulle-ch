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
@CrossOrigin(origins = "*")
public class AuthController {

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
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword())
            );

            // Se chegou aqui, as credenciais estão corretas e isAuthorized = true (ver CustomUserDetailsService)
            String token = jwtUtil.generateToken(request.getUsername());
            return ResponseEntity.ok(new LoginResponse(token));
        } catch (org.springframework.security.authentication.DisabledException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Usuário aguardando aprovação do Admin.");
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Credenciais inválidas");
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest request) {
        if (userRepository.findByUsername(request.getUsername()).isPresent()) {
            return ResponseEntity.badRequest().body("Usuário já existe.");
        }

        AppUser newUser = new AppUser();
        newUser.setUsername(request.getUsername());
        newUser.setName(request.getName());
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
class LoginRequest {
    private String username;
    private String password;
}

@Data
class LoginResponse {
    private final String token;
}

@Data
class RegisterRequest {
    private String username;
    private String password;
    private String name;
    private String avatarBase64;
}
