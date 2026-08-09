package com.mivan.ma.repository;

import com.mivan.ma.model.MaRafScore;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/** Repository for MA_RAF_SCORE — read access for post-adjudication RAF reporting. */
@Repository
public interface MaRafScoreRepository extends JpaRepository<MaRafScore, Long> {

    List<MaRafScore> findByMbi(String mbi);
}
