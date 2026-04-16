package com.memoryflow.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 英语单词表 (基于ECDICT词典)
 */
@TableName("english_words")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EnglishWord {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String word;

    private String phonetic;

    @TableField("definition")
    private String definition;

    @TableField("translation")
    private String translation;

    private String pos;

    private String tag; // cet4, cet6, toefl, gre, etc.

    @TableField("oxford")
    private Integer oxford; // 是否牛津核心词汇

    @TableField("collins")
    private Integer collins; // 柯林斯星级 1-5

    @TableField("bnc")
    private Integer bnc; // BNC词频排名

    @TableField("frq")
    private Integer frq; // COCA词频排名

    @TableField("exchange")
    private String exchange; // 词形变化

    private String detail;

    @TableField("audio_url")
    private String audioUrl;
}
