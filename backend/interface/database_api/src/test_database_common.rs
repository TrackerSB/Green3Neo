use crate::connection::DbConnection;

trait GetCurrentDBName {
    async fn get_current_db_name(&mut self) -> Option<String>
    where
        Self: sqlx::Connection;
}

impl GetCurrentDBName for sqlx::PgConnection {
    async fn get_current_db_name(&mut self) -> Option<String> {
        Some(
            sqlx::query_scalar("SELECT current_database()")
                .fetch_one(self)
                .await
                .expect("Querying current database name failed"),
        )
    }
}

impl GetCurrentDBName for sqlx::MySqlConnection {
    async fn get_current_db_name(&mut self) -> Option<String> {
        todo!("Not implemented")
    }
}

fn create_db_url(db_name: &str) -> String {
    let template_db_url = std::env::var("DATABASE_URL").expect("Could not determine database URL");
    template_db_url
        .split_at(
            template_db_url
                .rfind("/")
                .expect("Could not find slash separating DB address from DB name")
                + 1,
        )
        .0
        .to_owned()
        + db_name
}

pub trait IntoDieselConnection {
    async fn into_diesel_connection(self) -> DbConnection;
}

impl IntoDieselConnection for sqlx::pool::PoolConnection<sqlx::Postgres> {
    async fn into_diesel_connection(mut self) -> DbConnection {
        use diesel::Connection;

        let db_name = self.get_current_db_name().await.unwrap();
        let db_url = create_db_url(&db_name);
        DbConnection::PostgreSql(
            diesel::PgConnection::establish(&db_url).expect("Could not establish connection"),
        )
    }
}

impl IntoDieselConnection for sqlx::pool::PoolConnection<sqlx::MySql> {
    async fn into_diesel_connection(mut self) -> DbConnection {
        use diesel::Connection;

        let db_name = self.get_current_db_name().await.unwrap();
        let db_url = create_db_url(&db_name);
        DbConnection::MySql(
            diesel::MysqlConnection::establish(&db_url).expect("Could not establish connection"),
        )
    }
}
