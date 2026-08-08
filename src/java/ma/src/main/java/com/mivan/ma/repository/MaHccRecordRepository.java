package com.mivan.ma.repository;

import com.mivan.ma.model.MaHccRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MaHccRecordRepository extends JpaRepository<MaHccRecord, Long> {

    List<MaHccRecord> findByMbiAndPaymentYear(String mbi, String paymentYear);

    List<MaHccRecord> findByMbiAndValidationStatus(String mbi, String validationStatus);

    List<MaHccRecord> findByEncounterId(String encounterId);
}
