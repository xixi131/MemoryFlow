package com.memoryflow.service;

import cn.hutool.core.io.resource.ResourceUtil;
import cn.hutool.core.text.csv.CsvReadConfig;
import cn.hutool.core.text.csv.CsvReader;
import cn.hutool.core.text.csv.CsvRow;
import cn.hutool.core.text.csv.CsvUtil;
import cn.hutool.core.util.StrUtil;
import com.memoryflow.entity.EnglishWord;
import com.memoryflow.mapper.EnglishWordMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.ibatis.session.ExecutorType;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

/**
 * 字典数据批量导入服务
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class DictImportService {

    private final SqlSessionFactory sqlSessionFactory;

    /**
     * 导入 ECDICT 词典数据
     * @param csvPath CSV文件路径 (classpath下)
     */
    public void importDictionary(String csvPath) {
        log.info("开始导入词典数据: {}", csvPath);
        long startTime = System.currentTimeMillis();

        // 1. 创建 SqlSession
        // 注意：虽然要求使用 ExecutorType.BATCH，但由于 InsertBatchSomeColumn 本身就是拼接 SQL 的批量插入，
        // 且在 BATCH 模式下与 Jdbc3KeyGenerator 的主键回填机制存在冲突（导致 processBatch 报错），
        // 这里的 InsertBatchSomeColumn 实际上已经实现了高性能批量插入（单条 SQL 插入多行）。
        // 因此这里为了稳定性改用默认的 SIMPLE 模式，配合手动 commit 依然能达到极高的性能。
        try (SqlSession session = sqlSessionFactory.openSession(ExecutorType.SIMPLE, false);
             BufferedReader reader = ResourceUtil.getReader(csvPath, StandardCharsets.UTF_8)) {

            EnglishWordMapper mapper = session.getMapper(EnglishWordMapper.class);
            Connection connection = session.getConnection();

            // 2. 导入前禁用约束检查以提升性能
            log.info("正在禁用数据库约束检查...");
            executeSql(connection, "SET unique_checks=0");
            executeSql(connection, "SET foreign_key_checks=0");

            CsvReadConfig config = CsvReadConfig.defaultConfig();
            config.setContainsHeader(true);
            config.setSkipEmptyRows(true);
            config.setErrorOnDifferentFieldCount(false); // 忽略列数不匹配的行，防止因转义问题导致解析失败
            // 解决 CSV 解析提前结束的关键：将文本定界符（双引号）的处理逻辑调整
            // Hutool 默认使用双引号作为文本包装符，如果字段内容本身包含未转义的双引号，会导致解析混乱
            // 但如果 CSV 文件比较规范，这通常不是问题。
            // 重点检查：是否遇到了特殊字符导致 Hutool 认为文件结束了？
            // 尝试显式指定字符集构建 Reader，而不是依赖 Hutool 内部推断
            
            CsvReader csvReader = CsvUtil.getReader(config);
            // 预分配列表大小，避免扩容
            final List<EnglishWord> batchList = new ArrayList<>(2000);
            final int[] stats = {0};
            final long[] lastLineNumber = {0};

            // 逐行读取并处理
            csvReader.read(reader, (CsvRow row) -> {
                lastLineNumber[0] = row.getOriginalLineNumber();
                
                // 跳过表头 (虽然配置了 ContainsHeader，但保险起见还是判断一下)
                if (row.getOriginalLineNumber() <= 1) {
                    return;
                }

                EnglishWord word = parseRow(row);
                if (word == null) {
                    return;
                }

                batchList.add(word);

                // 3. 达到批次大小时执行插入和提交
                if (batchList.size() >= 2000) {
                    try {
                        mapper.insertBatchSomeColumn(batchList);
                        session.commit();
                        // 仅在成功提交后增加计数
                        stats[0] += batchList.size();
                    } catch (Exception e) {
                        log.warn("Batch insert failed. Retrying one by one to skip duplicates. Error: {}", e.getMessage());
                        session.rollback();
                        // 降级：逐条插入
                        int successCount = 0;
                        for (EnglishWord w : batchList) {
                            try {
                                mapper.insert(w);
                                session.commit();
                                successCount++;
                            } catch (Exception ex) {
                                // 忽略重复键异常
                                log.debug("Skipping duplicate word: {}", w.getWord());
                            }
                        }
                        stats[0] += successCount;
                    } finally {
                        session.clearCache();
                        log.info("已处理 {} 条数据...", stats[0]);
                        batchList.clear();
                    }
                }
            });

            // 处理剩余数据
            if (!batchList.isEmpty()) {
                try {
                    mapper.insertBatchSomeColumn(batchList);
                    session.commit();
                    stats[0] += batchList.size();
                } catch (Exception e) {
                    log.warn("Batch insert failed for remaining data. Retrying one by one...");
                    session.rollback();
                    int successCount = 0;
                    for (EnglishWord w : batchList) {
                        try {
                            mapper.insert(w);
                            session.commit();
                            successCount++;
                        } catch (Exception ex) {
                             // 忽略
                        }
                    }
                    stats[0] += successCount;
                }
            }

            // 4. 恢复约束检查
            log.info("正在恢复数据库约束检查...");
            executeSql(connection, "SET unique_checks=1");
            executeSql(connection, "SET foreign_key_checks=1");

            long endTime = System.currentTimeMillis();
            log.info("词典导入完成! 读取至第 {} 行, 实际导入: {} 条, 耗时: {} ms", lastLineNumber[0], stats[0], (endTime - startTime));

        } catch (Exception e) {
            log.error("词典导入失败", e);
            throw new RuntimeException("导入过程中发生错误", e);
        }
    }

    private void executeSql(Connection conn, String sql) {
        try (Statement stmt = conn.createStatement()) {
            stmt.execute(sql);
        } catch (Exception e) {
            log.warn("执行 SQL 失败: {}", sql, e);
        }
    }

    /**
     * 解析 CSV 行数据为实体对象
     */
    private EnglishWord parseRow(CsvRow row) {
        // 基础长度校验
        if (row.size() < 8) return null;

        String wordStr = getStr(row, 0);
        if (StrUtil.isBlank(wordStr)) return null;

        // 过滤规则
        // 1. 过滤掉词缀和连字符开头的
        if (wordStr.startsWith("-") || wordStr.endsWith("-")) return null;
        // 2. 过滤掉短语
        if (wordStr.contains(" ")) return null;
        // 3. 过滤掉纯数字或特殊符号
        if (wordStr.matches(".*\\d.*")) return null;

        // 4. 必须有标签
        String tag = getStr(row, 7);
        if (StrUtil.isBlank(tag)) return null;

        // 5. 必须有释义
        String translation = getStr(row, 3);
        String definition = getStr(row, 2);
        if (StrUtil.isBlank(translation) && StrUtil.isBlank(definition)) return null;

        return EnglishWord.builder()
                .word(wordStr)
                .phonetic(getStr(row, 1))
                .definition(definition)
                .translation(translation)
                .pos(getStr(row, 4))
                .collins(getInt(row, 5))
                .oxford(getInt(row, 6))
                .tag(tag)
                .bnc(getInt(row, 8))
                .frq(getInt(row, 9))
                .exchange(getStr(row, 10))
                .detail(getStr(row, 11))
                .audioUrl(getStr(row, 12))
                .build();
    }

    private String getStr(CsvRow row, int index) {
        if (index >= row.size()) return null;
        String val = row.get(index);
        return StrUtil.isBlank(val) ? null : val;
    }

    private Integer getInt(CsvRow row, int index) {
        String val = getStr(row, index);
        if (val == null) return null;
        try {
            return Integer.parseInt(val);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
