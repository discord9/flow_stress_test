CREATE TABLE IF NOT EXISTS h5_origin (
  `time` TIMESTAMP(3) NOT NULL,
  `env` STRING NULL,
  `service_name` STRING NULL,
  `span_name` STRING NULL,
  `page` STRING NULL,
  `pageId` STRING NULL,
  `ip` STRING NULL,
  `city` STRING NULL,
  `session` STRING NULL,
  `uid` STRING NULL,
  `user_id` STRING NULL,
  `username` STRING NULL,
  `os` STRING NULL,
  `osVs` STRING NULL,
  `browser` STRING NULL,
  `browserVs` STRING NULL,
  `code` STRING NULL,
  `msg` STRING NULL,
  `status_code` STRING NULL,
  `status_text` STRING NULL,
  `originPage` STRING NULL,
  `endpoint` STRING NULL,
  `tags` STRING NULL,
  `trace_id` STRING NULL,
  `duration` INT NULL,
  `lcp` BIGINT NULL,
  `fmp` BIGINT NULL,
  `fcp` BIGINT NULL,
  `fp` BIGINT NULL,
  `tti` BIGINT NULL,
  `fid` BIGINT NULL,
  `shard_key` BIGINT NULL,
  TIME INDEX (`time`),
  PRIMARY KEY (`env`, `service_name`)
)
PARTITION ON COLUMNS (`shard_key`) (
    shard_key < 4,
    shard_key >= 4 AND shard_key < 8,
    shard_key >= 8 AND shard_key < 12,
    shard_key >= 12 AND shard_key < 16,
    shard_key >= 16 AND shard_key < 20,
    shard_key >= 20 AND shard_key < 24,
    shard_key >= 24 AND shard_key < 28,
    shard_key >= 28 AND shard_key < 32,
    shard_key >= 32 AND shard_key < 36,
    shard_key >= 36 AND shard_key < 40,
    shard_key >= 40 AND shard_key < 44,
    shard_key >= 44 AND shard_key < 48,
    shard_key >= 48 AND shard_key < 52,
    shard_key >= 52 AND shard_key < 56,
    shard_key >= 56 AND shard_key < 60,
    shard_key >= 60
)
ENGINE=mito
WITH(
  append_mode = `true`,
  `compaction.twcs.max_output_file_size` = `2GB`,
  `compaction.twcs.time_window` = `1h`,
  `compaction.type` = `twcs`,
  ttl = `30d`
);

CREATE TABLE IF NOT EXISTS `h5_perf_1m` (
  `env` STRING NULL,
  `service_name` STRING NULL,
  `city` STRING NULL,
  `page` STRING NULL,
  `lcp_state` BINARY NULL,
  `max_lcp`   BIGINT NULL,
  `min_lcp`   BIGINT NULL,
  `fmp_state` BINARY NULL,
  `max_fmp`   BIGINT NULL,
  `min_fmp`   BIGINT NULL,
  `fcp_state` BINARY NULL,
  `max_fcp`   BIGINT NULL,
  `min_fcp`   BIGINT NULL,
  `fp_state`  BINARY NULL,
  `max_fp`    BIGINT NULL,
  `min_fp`    BIGINT NULL,
  `tti_state` BINARY NULL,
  `max_tti`   BIGINT NULL,
  `min_tti`   BIGINT NULL,
  `fid_state` BINARY NULL,
  `max_fid`   BIGINT NULL,
  `min_fid`   BIGINT NULL,
  `shard_key` BIGINT NULL,
  `time` TIMESTAMP(0) NOT NULL,
  TIME INDEX (`time`),
  PRIMARY KEY (`env`, `service_name`,`city`, `page`)
)
PARTITION ON COLUMNS (`shard_key`) (
    shard_key < 4,
    shard_key >= 4 AND shard_key < 8,
    shard_key >= 8 AND shard_key < 12,
    shard_key >= 12 AND shard_key < 16,
    shard_key >= 16 AND shard_key < 20,
    shard_key >= 20 AND shard_key < 24,
    shard_key >= 24 AND shard_key < 28,
    shard_key >= 28 AND shard_key < 32,
    shard_key >= 32 AND shard_key < 36,
    shard_key >= 36 AND shard_key < 40,
    shard_key >= 40 AND shard_key < 44,
    shard_key >= 44 AND shard_key < 48,
    shard_key >= 48 AND shard_key < 52,
    shard_key >= 52 AND shard_key < 56,
    shard_key >= 56 AND shard_key < 60,
    shard_key >= 60
)
ENGINE=mito
WITH(
  `compaction.twcs.max_output_file_size` = `2GB`,
  `compaction.type` = `twcs`,
  ttl = `180d`
);

CREATE FLOW dbg_flow 
SINK TO h5_perf_1m
AS SELECT env, service_name, city, page, 
uddsketch_state(128, 0.01, CASE WHEN lcp > 0 AND lcp < 3000000 THEN lcp ELSE NULL END) AS lcp_state, 
max(CASE WHEN lcp > 0 AND lcp < 3000000 THEN lcp ELSE NULL END) AS max_lcp, 
min(CASE WHEN lcp > 0 AND lcp < 3000000 THEN lcp ELSE NULL END) AS min_lcp, 
uddsketch_state(128, 0.01, CASE WHEN fmp > 0 AND fmp < 3000000 THEN fmp ELSE NULL END) AS fmp_state, 
max(CASE WHEN fmp > 0 AND fmp < 3000000 THEN fmp ELSE NULL END) AS max_fmp, 
min(CASE WHEN fmp > 0 AND fmp < 3000000 THEN fmp ELSE NULL END) AS min_fmp, 
uddsketch_state(128, 0.01, CASE WHEN fcp > 0 AND fcp < 3000000 THEN fcp ELSE NULL END) AS fcp_state, 
max(CASE WHEN fcp > 0 AND fcp < 3000000 THEN fcp ELSE NULL END) AS max_fcp, 
min(CASE WHEN fcp > 0 AND fcp < 3000000 THEN fcp ELSE NULL END) AS min_fcp,
 uddsketch_state(128, 0.01, CASE WHEN fp > 0 AND fp < 3000000 THEN fp ELSE NULL END) AS fp_state, 
 max(CASE WHEN fp > 0 AND fp < 3000000 THEN fp ELSE NULL END) AS max_fp, 
 min(CASE WHEN fp > 0 AND fp < 3000000 THEN fp ELSE NULL END) AS min_fp, 
 uddsketch_state(128, 0.01, CASE WHEN tti > 0 AND tti < 3000000 THEN tti ELSE NULL END) AS tti_state, 
 max(CASE WHEN tti > 0 AND tti < 3000000 THEN tti ELSE NULL END) AS max_tti, 
 min(CASE WHEN tti > 0 AND tti < 3000000 THEN tti ELSE NULL END) AS min_tti, 
 uddsketch_state(128, 0.01, CASE WHEN fid > 0 AND fid < 3000000 THEN fid ELSE NULL END) AS fid_state, 
 max(CASE WHEN fid > 0 AND fid < 3000000 THEN fid ELSE NULL END) AS max_fid, 
 min(CASE WHEN fid > 0 AND fid < 3000000 THEN fid ELSE NULL END) AS min_fid, 
 max(shard_key) AS shard_key, 

 date_bin('60 seconds'::INTERVAL, time)::TIMESTAMP(0) 
FROM h5_origin 
WHERE ((lcp > 0 AND lcp < 3000000) OR (fmp > 0 AND fmp < 3000000) OR (fcp > 0 AND fcp < 3000000) OR (fp > 0 AND fp < 3000000) OR (tti > 0 AND tti < 3000000) OR (fid > 0 AND fid < 3000000)) 
GROUP BY env, service_name, city, page, date_bin('60 seconds'::INTERVAL, time)::TIMESTAMP(0);

INSERT INTO h5_origin 
(
    `time`,
    `env`,
    `service_name`,
    `lcp`
)
VALUES 
(
    0,
    'test_env',
    'test_service',
    1234567
);

admin flush_flow('dbg_flow');

SELECT * FROM h5_perf_1m;

-- EXPLAIN ANALYZE SELECT env FROM h5_origin WHERE env in ('test_env');

-- test whether optimizer can optimize multiple OR into in list expression
-- EXPLAIN ANALYZE VERBOSE SELECT env FROM h5_origin WHERE env=='test_env' or env=='test_env_2' or env=='test_env_3' or env=='test_env_4' or env=='test_env_5' or env=='test_env_6' or env=='test_env_7' or env=='test_env_8' or env=='test_env_9' or env=='test_env_10';

-- EXPLAIN ANALYZE SELECT env FROM h5_origin WHERE env=='test_env' or env=='test_env_2';
