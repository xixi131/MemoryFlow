package com.memoryflow.dto.goal;

import com.memoryflow.entity.Goal;
import lombok.Data;
import lombok.Builder;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GoalDTO {

    private Long id;
    private String title;
    private String subtitle;
    private String labelType;
    private Integer progress;
    private String icon;
    private String colorClass;
    private String iconBgClass;
    private String progressGradient;
    private String status;
    private LocalDate dueDate;
    private List<SubjectSummary> subjects;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SubjectSummary {
        private Long id;
        private String title;
        private Integer progress;
        private String icon;
        private String colorClass;
    }

    public static GoalDTO fromEntity(Goal goal) {
        return GoalDTO.builder()
                .id(goal.getId())
                .title(goal.getTitle())
                .subtitle(goal.getSubtitle())
                .labelType(goal.getLabelType() != null ? goal.getLabelType().name() : "priority")
                .progress(goal.getProgress())
                .icon(goal.getIcon())
                .colorClass(goal.getColorClass())
                .iconBgClass(goal.getIconBgClass())
                .progressGradient(goal.getProgressGradient())
                .status(goal.getStatus().name())
                .dueDate(goal.getDueDate())
                .build();
    }
}
