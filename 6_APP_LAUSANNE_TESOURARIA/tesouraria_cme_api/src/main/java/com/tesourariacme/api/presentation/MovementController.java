package com.tesourariacme.api.presentation;

import com.tesourariacme.api.application.MovementService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/movements")
@RequiredArgsConstructor
public class MovementController {

    private final MovementService movementService;

    @GetMapping
    public ResponseEntity<MovementResponseDTO> getMovements(
            @RequestParam int year,
            @RequestParam int month) {
        return ResponseEntity.ok(movementService.getMovementsByMonth(year, month));
    }
}
