package com.memoryflow.dto.vocabulary;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CourseDTO {
    private Long id;
    private String name;
    private String code;
    private String description;
    private String coverImage;
    private Integer wordCount;
    private String category;
    private Integer difficulty;
    private String icon;
    private String colorTheme;

    // 用户学习进度
    private Integer learnedCount;
    private Integer dailyGoal;
    private Boolean isUserCourse;  // 用户是否已选择此课程
    private Double progress;       // 学习进度百分比
}
