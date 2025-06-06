use api::v1::{Column, ColumnDataType, InsertRequest, InsertRequests, SemanticType, column};
use clap::Parser;
use client::{Client, Database};
use common_telemetry::{error, info, logging::TracingOptions};
use serde::{Deserialize, Serialize};
use serde_json;

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    /// Random seed
    #[clap(short, long, default_value_t = 0)]
    seed: u64,
    /// Start index for writes
    #[clap(short = 'i', long, default_value_t = 0)]
    start_index: usize,
    /// Max out of order time range (in milliseconds)
    #[clap(short, long, default_value_t = 0)]
    max_out_of_order_ms: u64,
    /// Max number of unique combinations for gen_by columns (timeline limit)
    #[clap(long, default_value_t = 0)]
    max_timeline: usize,
    /// Rows per insert request
    #[clap(long, default_value_t = 3000)]
    rows_per_req: usize,
    /// Requests per second
    #[clap(long, default_value_t = 40_000)]
    rps: usize,
    /// GreptimeDB gRPC address
    #[clap(long, default_value = "localhost:4001")]
    grpc_addr: String,
    /// Path to the SQL file to create tables
    #[clap(long, default_value = "assets/create.sql")]
    create_sql_path: String,
    /// Path to the JSON file defining the table schema
    #[clap(long, default_value = "assets/base_table_schema.json")]
    schema_json_path: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct ColumnDef {
    name: String,
    #[serde(rename = "type")]
    data_type: String,
    #[serde(default = "default_semantic_type")]
    semantic: SemanticType,
}

#[derive(Debug, Serialize, Deserialize)]
struct Config {
    table_schema: Vec<ColumnDef>,
    gen_by: Vec<String>,
}

fn default_semantic_type() -> SemanticType {
    SemanticType::Field
}

fn gen_range_insert_reqs(
    table_name: &str,
    range: std::ops::Range<usize>,
    cfg: &Config,
    max_timeline: usize,
) -> InsertRequest {
    let column_defs = &cfg.table_schema;
    let mut columns = Vec::new();
    let row_count = range.len() as u32;

    for col_def in column_defs {
        let mut column = Column {
            column_name: col_def.name.clone(),
            ..Default::default()
        };

        match col_def.data_type.as_str() {
            "TIMESTAMP(3)" => {
                column.values = Some(column::Values {
                    timestamp_millisecond_values: range.clone().map(|i| i as i64).collect(),
                    ..Default::default()
                });
                column.semantic_type = col_def.semantic as i32;
                column.datatype = ColumnDataType::TimestampMillisecond as i32;
            }
            "STRING" => {
                let string_values: Vec<String> =
                    if cfg.gen_by.contains(&col_def.name) && max_timeline > 0 {
                        range
                            .clone()
                            .map(|i| format!("str_{}", i % max_timeline))
                            .collect()
                    } else {
                        range.clone().map(|i| format!("str_{}", i)).collect()
                    };
                column.values = Some(column::Values {
                    string_values,
                    ..Default::default()
                });
                column.semantic_type = col_def.semantic as i32;
                column.datatype = ColumnDataType::String as i32;
            }
            "BIGINT" => {
                column.values = Some(column::Values {
                    i64_values: range.clone().map(|i| i as i64).collect(),
                    ..Default::default()
                });
                column.semantic_type = col_def.semantic as i32;
                column.datatype = ColumnDataType::Int64 as i32;
            }
            // Add more types as needed
            _ => {
                info!("Unsupported column type: {}", col_def.data_type);
                continue;
            }
        }
        columns.push(column);
    }

    InsertRequest {
        table_name: table_name.to_string(),
        columns,
        row_count,
        ..Default::default()
    }
}

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

    let args = Args::parse();
    info!("Args: {:?}", args);

    let client = Client::with_urls(vec![args.grpc_addr.clone()]);
    let database = Database::new("greptime", "public", client);

    // Read create.sql and execute it
    let sql_content =
        std::fs::read_to_string(&args.create_sql_path).expect("Failed to read create.sql");
    for sql in sql_content.split(";") {
        if sql.is_empty() || sql.chars().all(|c| c.is_whitespace()) {
            continue;
        }
        let _res = database
            .sql(sql)
            .await
            .expect(format!("Failed to execute SQL: {}", sql).as_str());
    }

    // Read base_table_schema.json
    let schema_content = std::fs::read_to_string(&args.schema_json_path)
        .expect("Failed to read base_table_schema.json");
    let config: Config =
        serde_json::from_str(&schema_content).expect("Failed to parse base_table_schema.json");
    info!("Column definitions from JSON: {:?}", config.table_schema);

    let mut tick = tokio::time::interval(std::time::Duration::from_millis(1000));
    let mut cnt = args.start_index;

    loop {
        for _ in 0..args.rps / args.rows_per_req {
            let range = cnt..cnt + args.rows_per_req;
            let req = gen_range_insert_reqs("base_table", range, &config, args.max_timeline);
            let res = database.insert(InsertRequests { inserts: vec![req] }).await;
            if let Err(e) = res {
                error!(e; "Failed to insert {} rows", args.rows_per_req);
            }
            if cnt % (args.rps * 10) == 0 {
                info!("Total inserted {} rows", cnt);
            }
            cnt += args.rows_per_req;
        }

        tick.tick().await;
    }
}
