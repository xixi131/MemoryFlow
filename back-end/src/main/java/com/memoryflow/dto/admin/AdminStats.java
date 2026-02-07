package com.memoryflow.dto.admin;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AdminStats {
    private long totalUsers;
    private long newUsersThisMonth;
    private double whitelistUsageRate; // 百分比
    private long whitelistActivatedCount;
    private long whitelistTotalCount;
    private long activeUsersToday;
}
