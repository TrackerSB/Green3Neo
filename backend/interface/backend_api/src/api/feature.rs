use std::{collections::HashSet, sync::LazyLock};

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub enum Feature {
    FeatureSettings,
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
pub static ALWAYS_ON_FEATURES: LazyLock<HashSet<Feature>> =
    LazyLock::new(|| HashSet::from([BASE_FEATURE.clone(), Feature::FeatureSettings]));
// FIXME Verify that always on features are system features

pub struct FeatureDescription {
    // FIXME Localize feature names
    pub name: String,
    pub dependencies: Vec<Feature>, // FIXME Ensure there are no duplicates
    pub is_system_feature: bool,
}

impl FeatureDescription {
    fn new(name: String, mut dependencies: Vec<Feature>, is_system_feature: bool) -> Self {
        dependencies.push(BASE_FEATURE.clone());

        Self {
            name: name,
            dependencies: dependencies,
            is_system_feature: is_system_feature,
        }
    }
}

pub fn description(feature: Feature) -> FeatureDescription {
    match feature {
        Feature::FeatureSettings => {
            FeatureDescription::new("featureSettings".to_owned(), vec![], true)
        }
        Feature::MemberManagementMode => FeatureDescription::new(
            "memberManagementMode".to_owned(),
            vec![Feature::MemberView],
            false,
        ),
        Feature::MemberManagementView => {
            FeatureDescription::new("memberManagementView".to_owned(), vec![], false)
        }
        Feature::MemberView => FeatureDescription::new("memberView".to_owned(), vec![], false),
        Feature::Profiles => FeatureDescription::new("profiles".to_owned(), vec![], true),
        Feature::SepaGenerationWizard => FeatureDescription::new(
            "sepaGenerationWizard".to_owned(),
            vec![Feature::SepaManagementMode],
            false,
        ),
        Feature::SepaManagementMode => FeatureDescription::new(
            "sepaManagementMode".to_owned(),
            vec![Feature::MemberView],
            false,
        ),
        Feature::ViewManagementMode => FeatureDescription::new(
            "viewManagementMode".to_owned(),
            vec![Feature::MemberView],
            false,
        ),
    }
}
