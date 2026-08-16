extern crate proc_macro;

use proc_macro::TokenStream;
use quote::{ToTokens, quote};
use syn::{
    Attribute, Data, DeriveInput, Fields, GenericArgument, PathArguments, Type, parse_macro_input,
    parse_quote,
};

#[proc_macro_attribute]
pub fn make_fields_non_final(_attr: TokenStream, item: TokenStream) -> TokenStream {
    let input = parse_macro_input!(item as DeriveInput);

    let struct_name = &input.ident;
    let struct_fields = if let Data::Struct(data_struct) = &input.data {
        match &data_struct.fields {
            Fields::Named(named_fields) => &named_fields.named,
            Fields::Unnamed(unnamed_fields) => &unnamed_fields.unnamed,
            Fields::Unit => return TokenStream::from(quote! { #input }),
        }
    } else {
        return TokenStream::from(quote! { #input });
    };
    let struct_vis = &input.vis;

    let mut struct_attrs: Vec<Attribute> = input.attrs.clone();
    struct_attrs.push(parse_quote! {#[frb]});

    // Generate fields with attributes (currently not preserving existing ones)
    let modified_fields = struct_fields.iter().map(|f| {
        let field_vis = &f.vis;
        let field_name = &f.ident;
        let field_type = &f.ty;
        quote! {
            #[frb(non_final)]
            #field_vis #field_name: #field_type,
        }
    });

    // Generate the new struct with the modified fields
    let expanded = quote! {
        #(#struct_attrs)*
        #struct_vis struct #struct_name {
            #(#modified_fields)*
        }
    };

    TokenStream::from(expanded)
}

fn get_type_description(type_input: &Type) -> Option<(String, PathArguments)> {
    match type_input {
        Type::Path(type_path) => type_path
            .path
            .segments
            .last()
            .map(|segment| (segment.ident.to_string(), segment.arguments.clone())),
        _ => panic!("Type {} is unsupported", type_input.to_token_stream()),
    }
}

fn generate_conversion_function(type_input: &Type) -> proc_macro2::TokenStream {
    let type_description = get_type_description(type_input);
    match type_description {
        Some((type_name, type_params)) => match type_name.as_str() {
            "String" => {
                quote! {
                    Box::new(|content: &str| serde_json::Value::String(content.to_owned()))
                }
            }
            "i32" => {
                quote! {
                    Box::new(|content: &str| serde_json::Value::Number(content.parse::<i32>().unwrap().into()))
                }
            }
            "bool" => {
                quote! {
                    Box::new(|content: &str| {
                        serde_json::Value::Bool(
                            match content.to_lowercase().as_str() {
                                "true" | "1" => true,
                                "false" | "0" => false,
                                _ => panic!("Could not parse '{}' to bool", content),
                            })
                    })
                }
            }
            "Option" => {
                let PathArguments::AngleBracketed(angle_bracket_args) = type_params else {
                    panic!("Unsupported kind of path args");
                };
                let type_args = angle_bracket_args.args;
                assert_eq!(type_args.len(), 1);
                let GenericArgument::Type(inner_type) = type_args.first().unwrap() else {
                    panic!("Unsupported type of path args");
                };
                let inner_conversion = generate_conversion_function(inner_type);
                quote! {
                    // FIXME Do None values always arrive as "NULL"?
                    Box::new(|content: &str| {
                        if content == "NULL" {
                            return serde_json::Value::Null;
                        }

                        (#inner_conversion)(content)
                    })
                }
            }
            _ => panic!("Unsupported type name \"{}\"", type_name),
        },
        None => panic!(
            "Could not determine type name of type path \"{}\"",
            type_input.to_token_stream()
        ),
    }
}

#[proc_macro_derive(JsonFieldConversionGenerator)]
pub fn implement_json_field_conversion(item: TokenStream) -> TokenStream {
    let input = parse_macro_input!(item as DeriveInput);

    let struct_name = &input.ident;

    let struct_fields = if let Data::Struct(data_struct) = &input.data {
        match &data_struct.fields {
            Fields::Named(named_fields) => &named_fields.named,
            Fields::Unnamed(unnamed_fields) => &unnamed_fields.unnamed,
            Fields::Unit => return TokenStream::from(quote! { #input }),
        }
    } else {
        eprintln!("Struct is no data struct. Therefore not supported");
        return TokenStream::from(quote! { #input });
    };

    let field_conversion_cases = struct_fields.iter().map(|f| {
        let field_name = &f.ident;
        let field_case = field_name.as_ref().unwrap().to_string();
        let field_type = &f.ty;
        let conversion = generate_conversion_function(field_type);
        quote! {
            #field_case => #conversion,
        }
    });

    let expanded = quote! {
        impl JsonFieldConversion for #struct_name {
            #[frb(ignore)]
            fn get_json_value_generator(field_name: &str )-> Box<dyn Fn(&str) -> serde_json::Value> {
                match field_name {
                #(#field_conversion_cases)*
                _ => panic!("Field {} is unknown", field_name),
                }
            }
        }
    };

    TokenStream::from(expanded)
}
