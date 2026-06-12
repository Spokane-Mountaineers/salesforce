const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    // Keep sfdx-lwc-jest's stubs (lightning/*, other @salesforce/*) and add
    // a basePath stub so components that prefix the community basePath onto
    // hrefs are testable without a per-file mock.
    ...jestConfig.moduleNameMapper,
    "^@salesforce/community/basePath$":
      "<rootDir>/force-app/test/jest-mocks/@salesforce/community/basePath"
  }
};
