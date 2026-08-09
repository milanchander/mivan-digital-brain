package com.mivan.provider.validation.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Network Tier reference entity.
 *
 * <p>Maps the DB2 {@code NETWORK_TIER} reference table used by {@code MPRVNET0}
 * paragraph {@code 3200-GET-NETWORK-TIER} to resolve a tier code to its
 * descriptive attributes.</p>
 */
@Entity
@Table(name = "network_tier")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NetworkTier {

    @Id
    @Column(name = "tier_cd", length = 2)
    private String tierCd;

    @Column(name = "tier_name", length = 30)
    private String tierName;

    @Column(name = "tier_rank")
    private Integer tierRank;

    @Column(name = "description", length = 100)
    private String description;
}
