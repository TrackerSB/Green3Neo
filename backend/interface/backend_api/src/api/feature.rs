use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum Feature {
    MemberManagementMode,
    MemberView,
    Profiles,
    SepaGenerationWizard,
    SepaManagementMode,
    ViewManagementMode,
}

// The "profiles" features is always required since handling features itself is based on profiles
pub static BASE_FEATURE: Feature = Feature::Profiles;

pub struct FeatureDescription {
    // FIXME Localize feature names
    pub name: String,
    pub dependencies: Vec<Feature>,
}

pub fn description(feature: Feature) -> FeatureDescription {
    match feature {
        Feature::MemberManagementMode => FeatureDescription {
            name: "memberManagementMode".to_owned(),
            dependencies: vec![Feature::MemberView],
        },
        Feature::MemberView => FeatureDescription {
            name: "memberView".to_owned(),
            dependencies: vec![],
        },
        Feature::Profiles => FeatureDescription {
            name: "profiles".to_owned(),
            dependencies: vec![],
        },
        Feature::SepaGenerationWizard => FeatureDescription {
            name: "sepaGenerationWizard".to_owned(),
            dependencies: vec![Feature::SepaManagementMode],
        },
        Feature::SepaManagementMode => FeatureDescription {
            name: "sepaManagementMode".to_owned(),
            dependencies: vec![Feature::MemberView],
        },
        Feature::ViewManagementMode => FeatureDescription {
            name: "viewManagementMode".to_owned(),
            dependencies: vec![Feature::MemberView],
        },
    }
}
