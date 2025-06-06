-- base table, massive row insert to this table
CREATE TABLE IF NOT EXISTS base_table (
    `time` TIMESTAMP(3) NOT NULL,
    `env` STRING NULL,
    `service_name` STRING NULL,
    `city` STRING NULL,
    `page` STRING NULL,
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

-- 1m sink table
CREATE TABLE IF NOT EXISTS table_aggr_1m(
    `percentile_state` BINARY,
    `time_window` TIMESTAMP(3) TIME INDEX
);

-- flow for aggr to 1m
CREATE FLOW IF NOT EXISTS flow_aggr_1m SINK TO table_aggr_1m AS
SELECT
    uddsketch_state(128, 0.01, val) as percentile_state,
    date_bin('1 min' :: INTERVAL, `ts`) AS time_window
FROM
    base_table
GROUP BY
    time_window;

-- 10m sink table
CREATE TABLE IF NOT EXISTS table_aggr_10m(
    `percentile_state` BINARY,
    `time_window` TIMESTAMP(3) TIME INDEX
);

-- flow for aggr to 10m
CREATE FLOW IF NOT EXISTS flow_aggr_10m SINK TO table_aggr_10m AS
SELECT
    uddsketch_merge(128, 0.01, percentile_state) as percentile_state,
    date_bin('10 min' :: INTERVAL, time_window) AS time_window_10m
FROM
    table_aggr_1m
GROUP BY
    time_window_10m;

-- 1h sink table
CREATE TABLE IF NOT EXISTS table_aggr_1h(
    `percentile_state` BINARY,
    `time_window` TIMESTAMP(3) TIME INDEX
);

-- flow for aggr to 10m
CREATE FLOW IF NOT EXISTS flow_aggr_1h SINK TO table_aggr_1h AS
SELECT
    uddsketch_merge(128, 0.01, percentile_state) as percentile_state,
    date_bin('1 h' :: INTERVAL, time_window) AS time_window_1h
FROM
    table_aggr_1m
GROUP BY
    time_window_1h;