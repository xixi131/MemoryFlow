package com.memoryflow.dto.vocabulary;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * 学习会话 DTO
 * 用于传输一次学习会话中包含的所有单词（新词 + 复习词）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StudySessionDTO {
    /**
     * 会话中的单词列表
     */
    private List<WordDTO> words;

    /**
     * 本次会话包含的新词数量
     */
    private Integer newCount;

    /**
     * 本次会话包含的复习词数量
     */
    private Integer reviewCount;

    /**
     * 总单词数
     */
    private Integer totalCount;
}
