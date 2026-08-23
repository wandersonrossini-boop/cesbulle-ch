package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.MonthlyPeriod;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface MonthlyPeriodRepository extends JpaRepository<MonthlyPeriod, Long> {
    Optional<MonthlyPeriod> findByYearAndMonth(int year, int month);
}
