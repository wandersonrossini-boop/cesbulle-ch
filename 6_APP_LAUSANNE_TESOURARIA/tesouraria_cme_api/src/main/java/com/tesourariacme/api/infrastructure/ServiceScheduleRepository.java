package com.tesourariacme.api.infrastructure;

import com.tesourariacme.api.domain.ServiceSchedule;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.DayOfWeek;
import java.util.List;

@Repository
public interface ServiceScheduleRepository extends JpaRepository<ServiceSchedule, Long> {
    List<ServiceSchedule> findByActiveTrue();
    List<ServiceSchedule> findByDayOfWeekAndActiveTrue(DayOfWeek dayOfWeek);
}
