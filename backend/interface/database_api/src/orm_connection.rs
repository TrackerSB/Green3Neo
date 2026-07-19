use database_types::connection_description::DatabaseBackend;
#[cfg(feature = "mysql")]
use diesel::MysqlConnection;
#[cfg(feature = "postgres")]
use diesel::PgConnection;
use diesel::{MultiConnection, RunQueryDsl};
#[cfg(feature = "mysql")]
use sea_query::MysqlQueryBuilder;
#[cfg(feature = "postgres")]
use sea_query::PostgresQueryBuilder;
use sea_query::{QueryStatementWriter, TableCreateStatement};

use crate::{api::models, sql_stringifier::SqlStringifier};
use log::error;

#[derive(MultiConnection)]
pub enum OrmConnection {
    #[cfg(feature = "mysql")]
    MySql(MysqlConnection),
    #[cfg(feature = "postgres")]
    PostgreSql(PgConnection),
}

impl OrmConnection {
    pub fn get_backend(&self) -> DatabaseBackend {
        return match self {
            #[cfg(feature = "postgres")]
            Self::PostgreSql(_) => DatabaseBackend::PostgreSql,
            #[cfg(feature = "mysql")]
            Self::MySql(_) => DatabaseBackend::MySql,
        };
    }

    pub fn load_member<QueryType>(&mut self, sql_query: QueryType) -> Option<Vec<models::Member>>
    where
        QueryType: QueryStatementWriter,
        DatabaseBackend: SqlStringifier<QueryType>,
    {
        let sql_query_string = self.get_backend().to_sql_string(sql_query);

        let query_result = diesel::sql_query(&sql_query_string).load::<models::Member>(self);

        return match query_result {
            Ok(result) => Some(result),
            Err(error) => {
                error!(
                    "Executing query '{}' failed due '{}'",
                    sql_query_string, error
                );
                return None;
            }
        };
    }

    pub fn execute_sql<QueryType>(&mut self, sql_query: QueryType) -> Option<usize>
    where
        DatabaseBackend: SqlStringifier<QueryType>,
    {
        let sql_query_string = self.get_backend().to_sql_string(sql_query);

        let query_result = diesel::sql_query(&sql_query_string).execute(self);

        return match query_result {
            Ok(result) => Some(result),
            Err(error) => {
                error!(
                    "Executing query '{}' failed due '{}'",
                    sql_query_string, error
                );
                return None;
            }
        };
    }
}
