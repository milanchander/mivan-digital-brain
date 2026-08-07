package com.mivan.micps.repository;
import com.mivan.micps.model.NearDupQueue;
import org.springframework.data.jpa.repository.JpaRepository;
public interface NearDupQueueRepository extends JpaRepository<NearDupQueue, String> {}