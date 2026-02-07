package com.memoryflow.init;

import com.memoryflow.service.DictImportService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * 初始化导入 ECDICT 词典数据
 * 只有当 english_words 表为空时才会执行
 */
@Component
@Order(1)
@Slf4j
@RequiredArgsConstructor
public class EcdictDataLoader implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;
    private final DictImportService dictImportService;

    @Override
    public void run(String... args) throws Exception {
        log.info("Checking ECDICT data status...");
        
        Integer count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM english_words", Integer.class);
        // 修正阈值：有效考试词汇约为 1.5 万条，所以只要超过 1 万条就认为数据已就绪
        if (count != null && count > 10000) {
            log.info("ECDICT data already exists ({} records). Skipping import.", count);
            return;
        }
        
        if (count != null && count > 0) {
            log.info("Partial data detected ({} records). Deleting all records...", count);
            jdbcTemplate.execute("DELETE FROM english_words");
            jdbcTemplate.execute("ALTER TABLE english_words AUTO_INCREMENT = 1");
        }

        log.info("Starting ECDICT data import...");
        // 调用新的批量导入服务
        dictImportService.importDictionary("data/ecdict.csv");
    }
}
