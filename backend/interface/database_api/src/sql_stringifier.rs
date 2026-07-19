use database_types::connection_description::DatabaseBackend;
#[cfg(feature = "mysql")]
use sea_query::MysqlQueryBuilder;
#[cfg(feature = "postgres")]
use sea_query::PostgresQueryBuilder;
use sea_query::{SelectStatement, TableCreateStatement, UpdateStatement};

pub trait SqlStringifier<QueryType> {
    fn to_sql_string(&self, query: QueryType) -> String;
}

impl SqlStringifier<SelectStatement> for DatabaseBackend {
    fn to_sql_string(&self, query: SelectStatement) -> String {
        match self {
            #[cfg(feature = "postgres")]
            DatabaseBackend::PostgreSql => query.to_string(PostgresQueryBuilder),
            #[cfg(feature = "mysql")]
            DatabaseBackend::MySql => query.to_string(MysqlQueryBuilder),
        }
    }
}

impl SqlStringifier<TableCreateStatement> for DatabaseBackend {
    fn to_sql_string(&self, query: TableCreateStatement) -> String {
        match self {
            #[cfg(feature = "postgres")]
            DatabaseBackend::PostgreSql => query.to_string(PostgresQueryBuilder),
            #[cfg(feature = "mysql")]
            DatabaseBackend::MySql => query.to_string(MysqlQueryBuilder),
        }
    }
}

impl SqlStringifier<UpdateStatement> for DatabaseBackend {
    fn to_sql_string(&self, query: UpdateStatement) -> String {
        match self {
            #[cfg(feature = "postgres")]
            DatabaseBackend::PostgreSql => query.to_string(PostgresQueryBuilder),
            #[cfg(feature = "mysql")]
            DatabaseBackend::MySql => query.to_string(MysqlQueryBuilder),
        }
    }
}
