package com.memoryflow.dto.subject;

import com.memoryflow.entity.Subject;
import lombok.Data;
import lombok.Builder;
import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SubjectDTO {

    private Long id;
    private Long goalId;
    private String title;
    private Integer progress;
    private Integer totalTasks;
    private Integer completedTasks;
    private String icon;
    private String colorClass;
    private String bgClass;
    private String status;
    private List<ChapterDTO> chapters;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ChapterDTO {
        private Long id;
        private String title;
        private Integer totalPoints;     // Added
        private Integer completedPoints; // Added
        private List<ArticleDTO> contents; // Level 1 articles
        private List<PointSummary> children; // Level 2 points
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PointSummary {
        private Long id;
        private String title;
        private String status;
        private Boolean isLearned;
        private Boolean needsReview;
        private String nextReviewDate;
        private String lastReviewAt;
        private Boolean reviewCompleted;
        private Integer currentReviewStage;
        private List<ArticleDTO> contents; // Level 2 articles
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class ArticleDTO {
        private Long id;
        private String title;
        private String body; // Frontend uses 'body' for content
    }

    public static SubjectDTO fromEntity(Subject subject) {
        return SubjectDTO.builder()
                .id(subject.getId())
                .goalId(subject.getGoalId())
                .title(subject.getTitle())
                .progress(subject.getProgress())
                .totalTasks(subject.getTotalPoints())
                .completedTasks(subject.getCompletedPoints())
                .icon(subject.getIcon())
                .colorClass(subject.getColorClass())
                .bgClass(subject.getBgClass())
                .status(subject.getStatus().getValue())
                .build();
    }
}
