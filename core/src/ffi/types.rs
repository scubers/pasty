use crate::models::ContentType;

/// FFI-safe content type enum
#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum FfiContentType {
    Text = 0,
    Image = 1,
}

impl From<ContentType> for FfiContentType {
    fn from(ct: ContentType) -> Self {
        match ct {
            ContentType::Text => FfiContentType::Text,
            ContentType::Image => FfiContentType::Image,
        }
    }
}

impl From<FfiContentType> for ContentType {
    fn from(ffi_ct: FfiContentType) -> Self {
        match ffi_ct {
            FfiContentType::Text => ContentType::Text,
            FfiContentType::Image => ContentType::Image,
        }
    }
}

/// FFI error codes
#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum FfiErrorCode {
    Success = 0,
    InvalidArgument = 1,
    DatabaseError = 2,
    StorageError = 3,
    InternalError = 4,
    Unknown = 99,
}
