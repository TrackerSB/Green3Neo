use sea_query::{QueryStatementWriter, TableCreateStatement};

use crate::{api::models, orm_connection::OrmConnection, ssh_connection::SshConnection};

pub enum DbConnection {
    OrmBased(OrmConnection),
    SshBased(SshConnection),
}

impl DbConnection {
    pub fn to_string<QueryType: QueryStatementWriter>(&self, sql_query: QueryType) -> String {
        return match self {
            Self::OrmBased(connection) => connection.to_string(sql_query),
            Self::SshBased(connection) => connection.to_string(sql_query),
        };
    }

    pub async fn load_member<QueryType: QueryStatementWriter>(
        &mut self,
        sql_query: QueryType,
    ) -> Option<Vec<models::Member>> {
        return match self {
            Self::OrmBased(connection) => connection.load_member(sql_query),
            Self::SshBased(connection) => connection.load_member(sql_query).await,
        };
    }

    pub async fn execute_sql(&mut self, sql_query: TableCreateStatement) -> Option<usize> {
        return match self {
            Self::OrmBased(connection) => connection.execute_sql(sql_query),
            Self::SshBased(connection) => connection.execute_sql(sql_query).await,
        };
    }
}
