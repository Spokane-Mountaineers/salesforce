// Jest mock for @salesforce/community/basePath. At runtime LWR injects the
// site's path prefix (e.g. "/lwrsite"); under test it's the empty string, so
// basePath-prefixed hrefs assert as plain root-relative paths ("/post?...").
export default "";
