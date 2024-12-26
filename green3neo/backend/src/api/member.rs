use crate::models::Member;
use diesel::{
    query_dsl::methods::SelectDsl, Connection, PgConnection, RunQueryDsl, SelectableHelper,
};
use dotenv::dotenv;

fn get_connection() -> Option<PgConnection> {
    dotenv().ok();

    let url = std::env::var("DATABASE_URL");

    if url.is_err() {
        return None; // FIXME Improve error message
    }

    let connection = PgConnection::establish(&url.unwrap());

    if connection.is_err() {
        return None; // FIXME Improve error message
    }

    Some(connection.unwrap())
}

pub fn get_all_members() -> Option<Vec<Member>> {
    let connection = get_connection();

    if connection.is_none() {
        return None;
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

pub struct ChangeRecord {
    // Primary key for identification
    pub membershipid: i32,

    // Data to change
    pub column: String,
    pub value: Option<String>,
}

pub fn change_member(changes: Vec<ChangeRecord>) {
    println!("Changing data is not implemented");
    for change in changes {
        println!(
            "Change {} of {} to {:?}",
            change.membershipid, change.column, change.value
        );
    }
}
