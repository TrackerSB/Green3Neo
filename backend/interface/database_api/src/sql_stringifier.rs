use database_types::connection_description::DatabaseBackend;
use sea_query::{
    MysqlQueryBuilder, PostgresQueryBuilder, SelectStatement, TableCreateStatement, UpdateStatement,
};

pub trait SqlStringifier<QueryType> {
    fn to_sql_string(&self, query: QueryType) -> String;
}

impl SqlStringifier<SelectStatement> for DatabaseBackend {
    fn to_sql_string(&self, query: SelectStatement) -> String {
        match self {
            DatabaseBackend::PostgreSql => query.to_string(PostgresQueryBuilder),
            DatabaseBackend::MySql => query.to_string(MysqlQueryBuilder),
        }
    }
}

impl SqlStringifier<TableCreateStatement> for DatabaseBackend {
    fn to_sql_string(&self, query: TableCreateStatement) -> String {
        match self {
            DatabaseBackend::PostgreSql => query.to_string(PostgresQueryBuilder),
            DatabaseBackend::MySql => query.to_string(MysqlQueryBuilder),
        }
    }
}

impl SqlStringifier<UpdateStatement> for DatabaseBackend {
    fn to_sql_string(&self, query: UpdateStatement) -> String {
        match self {
            DatabaseBackend::PostgreSql => query.to_string(PostgresQueryBuilder),
            DatabaseBackend::MySql => query.to_string(MysqlQueryBuilder),
        }
    }
}
