use std::collections::HashMap;

use flutter_rust_bridge::{DartAbi, IntoDart, RustOpaque};

pub struct Member {
    pub id: u32,
    pub prename: String,
    pub surname: String,
}

pub fn get_member() -> Member {
    Member {
        id: 0,
        prename: "prename".to_owned(),
        surname: "surname".to_owned(),
    }
}

impl Member {
    pub fn get_id(&self) -> DartAbi {
        self.id.into_dart()
    }

    pub fn get_prename(&self) -> DartAbi {
        self.prename.as_str().into_dart()
    }

    pub fn get_surname(&self) -> DartAbi {
        self.surname.as_str().into_dart()
    }
}

/*
pub trait DBConnection<DataObject> {
    fn get_column_names(&self) -> Vec<String>;
    fn get_data() -> Vec<DataObject>;
    fn get_value_of(&self, member: DataObject, column_name: String) -> DartAbi;
}

// The following is not supported by FRB
impl DBConnection<Member> for MemberConnection{...}
*/

pub struct MemberConnection {
    pub retrievers: RustOpaque<HashMap<String, fn(&Member) -> DartAbi>>,
}

impl MemberConnection {
    pub fn get_column_names(&self) -> Vec<String> {
        self.retrievers.keys().cloned().collect()
    }

    pub fn get_value_of(&self, member: Member, column_name: String) -> DartAbi {
        self.retrievers
            .get(&column_name)
            .expect(&("Could not get value of column ".to_owned() + &column_name))(&member)
        .into_dart()
    }

    pub fn get_data() -> Vec<Member> {
        vec![
            Member {
                id: 1,
                prename: String::from("Sepp"),
                surname: String::from("Sepperson"),
            },
            Member {
                id: 2,
                prename: String::from("Jonny"),
                surname: String::from("Jonnson"),
            },
            Member {
                id: 3,
                prename: String::from("Benny"),
                surname: String::from("Benjamin"),
            },
        ]
    }
}

pub fn get_member_connection() -> MemberConnection {
    MemberConnection {
        retrievers: RustOpaque::new(HashMap::from([
            (
                "Nummer".to_owned(),
                Member::get_id as fn(&Member) -> DartAbi,
            ),
            ("Vorname".to_owned(), Member::get_prename),
        ])),
    }
}
