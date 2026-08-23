package com.tesourariacme.api.application;

import com.tesourariacme.api.domain.MonthlyPeriod;
import com.tesourariacme.api.domain.MonthlyPeriod.PeriodStatus;
import com.tesourariacme.api.infrastructure.MonthlyPeriodRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
public class MonthlyPeriodService {

    private final MonthlyPeriodRepository repository;

    public MonthlyPeriodService(MonthlyPeriodRepository repository) {
        this.repository = repository;
    }

    public boolean isPeriodLocked(int year, int month) {
        return repository.findByYearAndMonth(year, month)
                .map(p -> p.getStatus() == PeriodStatus.LOCKED)
                .orElse(false);
    }

    public boolean isPeriodLocked(LocalDate date) {
        if (date == null) return false;
        return isPeriodLocked(date.getYear(), date.getMonthValue());
    }

    @Transactional
    public MonthlyPeriod lockPeriod(int year, int month, String username) {
        MonthlyPeriod period = repository.findByYearAndMonth(year, month)
                .orElseGet(() -> {
                    MonthlyPeriod p = new MonthlyPeriod();
                    p.setYear(year);
                    p.setMonth(month);
                    return p;
                });

        period.setStatus(PeriodStatus.LOCKED);
        period.setLockedBy(username);
        period.setLockedAt(LocalDateTime.now());
        return repository.save(period);
    }

    @Transactional
    public MonthlyPeriod unlockPeriod(int year, int month) {
        MonthlyPeriod period = repository.findByYearAndMonth(year, month)
                .orElseGet(() -> {
                    MonthlyPeriod p = new MonthlyPeriod();
                    p.setYear(year);
                    p.setMonth(month);
                    return p;
                });

        period.setStatus(PeriodStatus.OPEN);
        period.setLockedBy(null);
        period.setLockedAt(null);
        return repository.save(period);
    }

    public String getPeriodStatus(int year, int month) {
        return repository.findByYearAndMonth(year, month)
                .map(p -> p.getStatus().name())
                .orElse("OPEN");
    }
}
