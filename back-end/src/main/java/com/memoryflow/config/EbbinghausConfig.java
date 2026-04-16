package com.memoryflow.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.List;

@Data
@Component
@ConfigurationProperties(prefix = "ebbinghaus")
public class EbbinghausConfig {

    /**
     * 艾宾浩斯复习周期(天数)
     * 默认: [1, 2, 4, 7, 15, 30, 90, 180]
     */
    private List<Integer> cycles = List.of(1, 2, 4, 7, 15, 30, 90, 180);

    /**
     * 获取指定阶段的间隔天数
     * @param stage 复习阶段 (1-8)
     * @return 间隔天数
     */
    public int getIntervalDays(int stage) {
        if (stage < 1 || stage > cycles.size()) {
            throw new IllegalArgumentException("Invalid review stage: " + stage);
        }
        return cycles.get(stage - 1);
    }

    /**
     * 获取总复习阶段数
     */
    public int getTotalStages() {
        return cycles.size();
    }
}
