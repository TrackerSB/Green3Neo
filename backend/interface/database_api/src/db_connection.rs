use database_types::connection_description::DatabaseBackend;
use sea_query::QueryStatementWriter;

use crate::{
    api::models, orm_connection::OrmConnection, sql_stringifier::SqlStringifier,
    ssh_connection::SshConnection,
};

pub enum DbConnection {
    OrmBased(OrmConnection),
    SshBased(SshConnection),
}

impl DbConnection {
    pub fn get_backend(&self) -> DatabaseBackend {
        return match self {
            Self::OrmBased(connection) => connection.get_backend(),
            Self::SshBased(connection) => connection.get_backend(),
        };
    }

    pub async fn load_member<QueryType: QueryStatementWriter>(
        &mut self,
        sql_query: QueryType,
    ) -> Option<Vec<models::Member>>
    where
        QueryType: QueryStatementWriter,
        DatabaseBackend: SqlStringifier<QueryType>,
    {
        return match self {
            Self::OrmBased(connection) => connection.load_member(sql_query),
            Self::SshBased(connection) => connection.load_member(sql_query).await,
        };
    }

    pub async fn execute_sql<QueryType>(&mut self, sql_query: QueryType) -> Option<usize>
    where
        DatabaseBackend: SqlStringifier<QueryType>,
    {
        return match self {
            Self::OrmBased(connection) => connection.execute_sql(sql_query),
            Self::SshBased(connection) => connection.execute_sql(sql_query).await,
        };
    }
}
