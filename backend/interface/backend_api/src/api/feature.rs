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
// FIXME Verify that no system feature has a dependency to a profile feature

pub struct FeatureDescription {
    // FIXME Localize feature names
    pub name: String,
    pub dependencies: Vec<Feature>, // FIXME Ensure there are no duplicates
    pub is_system_feature: bool,
}

impl FeatureDescription {
    fn new(
        feature: Feature,
        name: String,
        mut dependencies: Vec<Feature>,
        is_system_feature: bool,
    ) -> Self {
        if feature != BASE_FEATURE.clone() {
            dependencies.push(BASE_FEATURE.clone());
        }

        Self {
            name: name,
            dependencies: dependencies,
            is_system_feature: is_system_feature,
        }
    }
}

// FIXME Detect cycles in dependencies
pub fn get_feature_description(feature: Feature) -> FeatureDescription {
    match feature {
        Feature::FeatureSettings => FeatureDescription::new(
            Feature::FeatureSettings,
            "featureSettings".to_owned(),
            vec![],
            true,
        ),
        Feature::MemberManagementMode => FeatureDescription::new(
            Feature::MemberManagementMode,
            "memberManagementMode".to_owned(),
            vec![Feature::MemberView],
            false,
        ),
        Feature::MemberManagementView => FeatureDescription::new(
            Feature::MemberManagementView,
            "memberManagementView".to_owned(),
            vec![],
            false,
        ),
        Feature::MemberView => {
            FeatureDescription::new(Feature::MemberView, "memberView".to_owned(), vec![], false)
        }
        Feature::Profiles => {
            FeatureDescription::new(Feature::Profiles, "profiles".to_owned(), vec![], true)
        }
        Feature::SepaGenerationWizard => FeatureDescription::new(
            Feature::SepaGenerationWizard,
            "sepaGenerationWizard".to_owned(),
            vec![],
            false,
        ),
        Feature::SepaManagementMode => FeatureDescription::new(
            Feature::SepaManagementMode,
            "sepaManagementMode".to_owned(),
            vec![Feature::MemberView, Feature::SepaGenerationWizard],
            false,
        ),
        Feature::ViewManagementMode => FeatureDescription::new(
            Feature::ViewManagementMode,
            "viewManagementMode".to_owned(),
            vec![Feature::MemberView],
            false,
        ),
    }
}
