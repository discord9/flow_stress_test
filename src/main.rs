use std::path::PathBuf;

use api::v1::{Column, ColumnDataType, InsertRequest, InsertRequests, SemanticType, column};
use client::{Client, Database};
use common_telemetry::{error, info, logging::TracingOptions};

// TODO: more time series & more out of order, and options

fn gen_range_insert_reqs(table_name: &str, range: std::ops::Range<usize>) -> InsertRequest {
    let ids = range.clone().map(|i| i as i32).collect::<Vec<_>>();
    let vals = range.clone().map(|i| i as f64).collect::<Vec<_>>();
    let ts = range.clone().map(|i| i as i64).collect::<Vec<_>>();

    let id_col = Column {
        column_name: "id".to_string(),
        values: Some(column::Values {
            i32_values: ids,
            ..Default::default()
        }),
        semantic_type: SemanticType::Tag as i32,
        datatype: ColumnDataType::Int32 as i32,
        ..Default::default()
    };

    let val_col = Column {
        column_name: "val".to_string(),
        values: Some(column::Values {
            f64_values: vals,
            ..Default::default()
        }),
        semantic_type: SemanticType::Field as i32,
        datatype: ColumnDataType::Float64 as i32,
        ..Default::default()
    };

    let ts_col = Column {
        column_name: "ts".to_string(),
        values: Some(column::Values {
            timestamp_millisecond_values: ts,
            ..Default::default()
        }),
        semantic_type: SemanticType::Timestamp as i32,
        datatype: ColumnDataType::TimestampMillisecond as i32,
        ..Default::default()
    };

    let request = InsertRequest {
        table_name: table_name.to_string(),
        columns: vec![id_col, val_col, ts_col],
        row_count: range.len() as u32,
        ..Default::default()
    };
    request
}

const ROWS_PER_REQ: usize = 3000;
const RPS: usize = 40_000;
const APP_NAME: &str = "flow_stress_test";

#[tokio::main]
async fn main() {
    let _guard = common_telemetry::init_global_logging(
        APP_NAME,
        &Default::default(),
        &TracingOptions::default(),
        None,
        None,
    );
    let client = Client::with_urls(vec!["localhost:4001".to_string()]);
    let database = Database::new("greptime", "public", client);

    let mut path = PathBuf::new();
    path.push("assets");
    path.push("create.sql");

    let sql = std::fs::read_to_string(path).expect("Failed to read create_table.sql");
    for sql in sql.split(";") {
        if sql.is_empty() || sql.chars().all(|c| c.is_whitespace()) {
            continue;
        }
        let _res = database
            .sql(sql)
            .await
            .expect(format!("Failed to execute SQL: {}", sql).as_str());
    }

    let mut tick = tokio::time::interval(std::time::Duration::from_millis(1000));
    let mut cnt = 39000;
    loop {
        for _ in 0..RPS / ROWS_PER_REQ {
            let range = cnt..cnt + ROWS_PER_REQ;
            let req = gen_range_insert_reqs("base_table", range);
            let res = database.insert(InsertRequests { inserts: vec![req] }).await;
            if let Err(e) = res {
                error!(e; "Failed to insert {} rows", ROWS_PER_REQ);
            }
            if cnt % (RPS * 10) == 0 {
                info!("Total inserted {} rows", cnt);
            }
            cnt += ROWS_PER_REQ;
        }

        tick.tick().await;
    }
}
