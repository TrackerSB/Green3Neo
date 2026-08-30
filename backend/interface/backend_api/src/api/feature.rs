use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum Feature {
    MemberManagementMode,
    MemberManagementView,
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
    pub dependencies: Vec<Feature>, // FIXME Ensure there are no duplicates
}

impl FeatureDescription {
    fn new(name: String, mut dependencies: Vec<Feature>) -> Self {
        dependencies.push(BASE_FEATURE.clone());

        Self {
            name: name,
            dependencies: dependencies,
        }
    }
}

pub fn description(feature: Feature) -> FeatureDescription {
    match feature {
        Feature::MemberManagementMode => {
            FeatureDescription::new("memberManagementMode".to_owned(), vec![Feature::MemberView])
        }
        Feature::MemberManagementView => FeatureDescription {
            name: "memberManagementView".to_owned(),
            dependencies: vec![],
        },
        Feature::MemberView => FeatureDescription::new("memberView".to_owned(), vec![]),
        Feature::Profiles => FeatureDescription::new("profiles".to_owned(), vec![]),
        Feature::SepaGenerationWizard => FeatureDescription::new(
            "sepaGenerationWizard".to_owned(),
            vec![Feature::SepaManagementMode],
        ),
        Feature::SepaManagementMode => {
            FeatureDescription::new("sepaManagementMode".to_owned(), vec![Feature::MemberView])
        }
        Feature::ViewManagementMode => {
            FeatureDescription::new("viewManagementMode".to_owned(), vec![Feature::MemberView])
        }
    }
}
