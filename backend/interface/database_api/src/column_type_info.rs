use log::{trace, warn};

use diesel::{
    QueryableByName, RunQueryDsl,
    sql_types::{Text, Varchar},
};

use crate::connection::DbConnection;

#[derive(Debug)]
pub struct ColumnTypeInfo {
    pub column_name: String,
    pub data_type: String,
    pub is_array: bool,
    pub is_nullable: bool,
}

pub fn get_type_of_array(array_type: &str) -> Option<&str> {
    match array_type {
        "_int4" => Some("integer"),
        _ => None,
    }
}

#[derive(QueryableByName, Debug)]
struct ColumnTypeRequestResult {
    #[diesel(sql_type = Text)]
    pub column_name: String,
    #[diesel(sql_type = Text)]
    pub data_type: String,
    #[diesel(sql_type = Text)]
    pub udt_name: String,
    #[diesel(sql_type = Text)]
    pub is_nullable: String,
}

pub fn get_column_info(
    connection: &mut DbConnection,
    table_name: &str,
    column_name: &str,
) -> Option<ColumnTypeInfo> {
    let query = diesel::sql_query(
        "SELECT column_name, data_type, udt_name, is_nullable \
        FROM information_schema.columns \
        WHERE table_name = $1 AND column_name = $2",
    )
    .bind::<Varchar, _>(table_name)
    .bind::<Varchar, _>(column_name);
    trace!("query: {:?}", query);
    let derived_column_types = query.load::<ColumnTypeRequestResult>(connection);

    if derived_column_types.is_err() {
        warn!(
            "Could not determine column types due '{}'",
            derived_column_types.err().unwrap()
        );
        return None;
    }

    assert!(derived_column_types.is_ok());

    let num_column_types = derived_column_types.as_ref().unwrap().len();
    if num_column_types == 0 {
        warn!("Could not determine column type of '{}'", column_name);
        return None;
    }
    if num_column_types > 1 {
        warn!("Column type is ambiguous");
        return None;
    }

    let column_type_result: ColumnTypeRequestResult = derived_column_types.unwrap().pop().unwrap();
    let is_array = column_type_result.data_type == "ARRAY";
    let is_nullable = column_type_result.is_nullable == "YES";

    if is_array {
        let array_type = get_type_of_array(column_type_result.udt_name.as_str());
        if array_type.is_none() {
            warn!("Unknown array type {}", column_type_result.udt_name);
            return None;
        }
        return Some(ColumnTypeInfo {
            column_name: column_type_result.column_name,
            data_type: array_type.unwrap().to_owned(),
            is_array,
            is_nullable,
        });
    }

    Some(ColumnTypeInfo {
        column_name: column_type_result.column_name,
        data_type: column_type_result.data_type,
        is_array,
        is_nullable,
    })
}

#[cfg(test)]
mod test {
    use backend_testing::testing;
    use speculoos::{assert_that, option::OptionAssertions, vec::VecAssertions};
    use sqlx::PgPool;

    use crate::test_database_common::{get_all_column_info, to_diesel_connection};

    use super::*;

    fn setup_test() {
        testing::setup_test();
    }

    fn tear_down(expected_num_severe_messages: usize) {
        testing::tear_down(expected_num_severe_messages);
    }

    #[sqlx::test(fixtures("allsupportedtypes"))]
    async fn test_determine_column_type(pool: PgPool) -> sqlx::Result<()> {
        setup_test();

        // FIXME Determine table name automatically
        let table_name = "allsupportedtypes";
        let mut test_connection = pool.acquire().await?;

        let column_info = get_all_column_info(&mut test_connection, table_name).await;
        assert_that!(&column_info)
            .named("Gather columns to check")
            .is_not_empty();

        let mut diesel_connection = to_diesel_connection(&mut test_connection).await;

        for row in column_info.iter() {
            let expected_column_name = &row.column_name;
            let expected_data_type = &row.data_type;
            let expected_is_array = &row.is_array;
            let expected_is_nullable = &row.is_nullable;

            let opt_actual_column_type: Option<ColumnTypeInfo> =
                get_column_info(&mut diesel_connection, table_name, &expected_column_name);
            assert_that!(&opt_actual_column_type)
                .named("Determine column type")
                .is_some()
                .matches(|actual_column_type| {
                    &actual_column_type.column_name == expected_column_name
                })
                .matches(|actual_column_type| &actual_column_type.data_type == expected_data_type)
                .matches(|actual_column_type| &actual_column_type.is_array == expected_is_array)
                .matches(|actual_column_type| {
                    &actual_column_type.is_nullable == expected_is_nullable
                });
        }

        tear_down(0);
        Ok(())
    }
}
