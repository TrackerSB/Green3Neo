use crate::models::Member;
use diesel::{
    query_dsl::methods::SelectDsl, Connection, PgConnection, RunQueryDsl, SelectableHelper,
};
use dotenv::dotenv;

pub fn get_dummy_members() -> Option<Vec<Member>> {
    dotenv().ok();

    let url = std::env::var("DATABASE_URL");

    if url.is_err() {
        return None; // FIXME Improve error message
    }

    let connection = PgConnection::establish(&url.unwrap());

    if connection.is_err() {
        return None; // FIXME Improve error message
    }

    use crate::schema::member::dsl::*;

    let member_entries = member
        .select(Member::as_select())
        .load(&mut connection.unwrap());

    if member_entries.is_err() {
        return None; // FIXME Improve error message
    }

    Some(member_entries.unwrap())
}
