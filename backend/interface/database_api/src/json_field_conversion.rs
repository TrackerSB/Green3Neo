pub trait JsonFieldConversion {
    fn get_json_value_generator(field_name: &str) -> Box<dyn Fn(&str) -> serde_json::Value>;
}
