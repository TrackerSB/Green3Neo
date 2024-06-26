// use chrono::NaiveDate;

//use std::collections::HashMap;
use crate::models::Member;
//use flutter_rust_bridge::{DartAbi, IntoDart, RustOpaque};

// #[flutter_rust_bridge::frb(init)]
// pub fn init_app(){
//     flutter_rust_bridge::setup_default_user_utils();
// }

/*
pub struct MemberConnection {
    pub foo: u32,
}
*/

/* The following methods create dummy instances of classes to ensure they're not optimized away before FRB code
 * generation
 */
pub fn get_dummy_member() -> Member {
    Member {
        membershipid: 42,
        prename: String::default(),
        surname: String::default(),
        title: None,
        ismale: true,
        // birthday: NaiveDate::default(),
        street: String::default(),
        housenumber: String::default(),
        zipcode: String::default(),
        city: String::default(),
        isactive: true,
        isfoundingmember: true,
        ishonorarymember: true,
        iscontributionfree: true,
        contributorsinceyear: None,
        // joindate: NaiveDate::default(),
        // exitdate: None,
        phonenumber: None,
        mobilenumber: None,
        email: None,
        accountholderprename: None,
        accountholdersurname: None,
        iban: String::default(),
        bic: String::default(),
        // mandatesince: NaiveDate::default(),
        honoraryyears: None,
        contributionhonoraryyears: None,
        hasgauehrenzeichen: true,
        isehrenschriftf_hrer: true,
        isehrenvorstand: true,
        ismemberofboard: true,
    }
}
/*
pub fn get_dummy_member_connection() -> MemberConnection {
    MemberConnection { foo: 42 }
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
                Member::id as fn(&Member) -> DartAbi,
            ),
            ("Vorname".to_owned(), Member::prename),
        ])),
    }
}
*/
