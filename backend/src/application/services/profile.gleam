import gleam/string
import shared/api/error as api_error

pub type BioValidation {
  BioValid
  BioTooLong
}

pub fn validate_bio(bio: String) -> BioValidation {
  case string.length(bio) > api_error.bio_max_length {
    True -> BioTooLong
    False -> BioValid
  }
}
