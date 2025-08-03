// @generated automatically by Diesel CLI.

diesel::table! {
    member (membershipid) {
        membershipid -> Int4,
        #[max_length = 255]
        prename -> Varchar,
        #[max_length = 255]
        surname -> Varchar,
        #[max_length = 15]
        title -> Nullable<Varchar>,
        ismale -> Bool,
        #[max_length = 255]
        street -> Varchar,
        #[max_length = 255]
        housenumber -> Varchar,
        #[max_length = 255]
        zipcode -> Varchar,
        #[max_length = 255]
        city -> Varchar,
        isactive -> Bool,
        isfoundingmember -> Bool,
        ishonorarymember -> Bool,
        iscontributionfree -> Bool,
        contributorsinceyear -> Nullable<Int4>,
        #[max_length = 255]
        phonenumber -> Nullable<Varchar>,
        #[max_length = 255]
        mobilenumber -> Nullable<Varchar>,
        #[max_length = 255]
        email -> Nullable<Varchar>,
        #[max_length = 255]
        accountholderprename -> Nullable<Varchar>,
        #[max_length = 255]
        accountholdersurname -> Nullable<Varchar>,
        #[max_length = 255]
        iban -> Varchar,
        #[max_length = 255]
        bic -> Varchar,
        honoraryyears -> Nullable<Array<Nullable<Int4>>>,
        contributionhonoraryyears -> Nullable<Array<Nullable<Int4>>>,
        hasgauehrenzeichen -> Bool,
        #[sql_name = "isehrenschriftführer"]
        isehrenschriftf_hrer -> Bool,
        isehrenvorstand -> Bool,
        ismemberofboard -> Bool,
    }
}
