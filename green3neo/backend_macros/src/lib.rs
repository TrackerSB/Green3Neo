extern crate proc_macro;

use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, parse_quote, Attribute, Data, DeriveInput, Fields};

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
    struct_attrs.push(parse_quote!{#[frb]});

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
