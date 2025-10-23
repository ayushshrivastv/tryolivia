//! OLIVIA Encrypted Instructions
//! 
//! This module contains Arcium MPC circuits for privacy-preserving
//! message routing, delivery verification, and private information retrieval.
//! 
//! All computations run within Arcium's multi-party computation environment,
//! ensuring that sensitive data remains encrypted throughout processing.

pub mod routing;
pub mod delivery;
pub mod pir;

// Re-export public interfaces for external consumption
pub use routing::*;
pub use delivery::*;
pub use pir::*;
