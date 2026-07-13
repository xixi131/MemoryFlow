package com.memoryflow.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.memoryflow.entity.EnglishWord;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface EnglishWordMapper extends MyBaseMapper<EnglishWord> {

    @Select("SELECT * FROM english_words WHERE word LIKE CONCAT(#{prefix}, '%')")
    List<EnglishWord> findByWordStartingWith(@Param("prefix") String prefix);

    @Select("SELECT * FROM english_words WHERE word LIKE CONCAT('%', #{keyword}, '%') OR translation LIKE CONCAT('%', #{keyword}, '%')")
    IPage<EnglishWord> searchWords(Page<EnglishWord> page, @Param("keyword") String keyword);

    @Select("SELECT * FROM english_words WHERE collins >= #{minStar} ORDER BY collins DESC, bnc ASC")
    List<EnglishWord> findHighFrequencyWords(Page<EnglishWord> page, @Param("minStar") Integer minStar);
}
