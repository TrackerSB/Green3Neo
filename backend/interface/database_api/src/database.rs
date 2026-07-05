#[cfg(test)]
mod test {
    use std::fs;

    use backend_testing::testing;
    #[cfg(feature = "mysql")]
    use sqlx::MySqlPool;
    #[cfg(feature = "postgres")]
    use sqlx::PgPool;
    use sqlx::{Database, Pool, any::install_default_drivers, pool::PoolConnection};

    use crate::{connection::OrmConnection, test_database_common::IntoDieselConnection};

    use super::*;

    async fn setup_test<DB>(sqlx_pool: Pool<DB>) -> OrmConnection
    where
        DB: Database,
        PoolConnection<DB>: IntoDieselConnection,
    {
        testing::setup_test();

        install_default_drivers(); // FIXME Required?

        let sqlx_connection = sqlx_pool.acquire().await.unwrap();
        let mut diesel_connection = sqlx_connection.into_diesel_connection().await;

        let fixture_sql_content = fs::read_to_string("src/fixtures/allsupportedtypes.sql").unwrap();
        diesel_connection.execute_sql(fixture_sql_content);

        diesel_connection
    }

    fn tear_down(expected_num_severe_messages: usize) {
        testing::tear_down(expected_num_severe_messages);
    }

    #[cfg(feature = "postgres")]
    #[sqlx::test]
    async fn test_stub_pg(pool: PgPool) -> sqlx::Result<()> {
        let _connection = setup_test(pool).await;
        tear_down(0);
        Ok(())
    }

    #[cfg(feature = "mysql")]
    #[sqlx::test]
    async fn test_stub_mysql(pool: MySqlPool) -> sqlx::Result<()> {
        let _connection = setup_test(pool).await;
        tear_down(0);
        Ok(())
    }
}
