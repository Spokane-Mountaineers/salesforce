/**
 * Tests for CommunityLoginController (plan §8). Site.login can't authenticate a
 * real user in a test context (returns null), so these cover validation, the
 * `.smi` normalization, the no-auth failure path, and the config URLs. A real
 * end-to-end sign-in is verified manually against staging.
 */
@isTest
private class CommunityLoginControllerTest {
  @isTest
  static void login_blankInput_returnsValidationMessage() {
    CommunityLoginController.LoginResult r = CommunityLoginController.login(
      '',
      '',
      null
    );
    System.assertEquals(false, r.success);
    System.assert(
      r.message.contains('username'),
      'Expected a validation message'
    );
  }

  @isTest
  static void login_badCredentials_returnsFailure() {
    CommunityLoginController.LoginResult r = CommunityLoginController.login(
      'nobody@example.com',
      'wrong-password',
      '/s/'
    );
    // Site.login returns null for unauthenticatable creds → failure, no redirect.
    System.assertEquals(false, r.success);
    System.assertEquals(null, r.redirectUrl);
    System.assertNotEquals(null, r.message);
  }

  @isTest
  static void normalizeUsername_appendsSmiSuffixOnce() {
    System.assertEquals(
      'a@b.com.smi',
      CommunityLoginController.normalizeUsername('a@b.com')
    );
    System.assertEquals(
      'a@b.com.smi',
      CommunityLoginController.normalizeUsername('a@b.com.smi'),
      'Already-suffixed username must not double up'
    );
    System.assertEquals(
      'a@b.com.SMI',
      CommunityLoginController.normalizeUsername('a@b.com.SMI'),
      'Case-insensitive suffix check must not double-append (case preserved)'
    );
  }

  @isTest
  static void getLoginConfig_returnsProviderUrls() {
    CommunityLoginController.LoginConfig cfg = CommunityLoginController.getLoginConfig();
    System.assert(cfg.googleUrl.endsWith('/services/auth/sso/Google'));
    System.assert(cfg.microsoftUrl.endsWith('/services/auth/sso/Microsoft'));
    System.assert(cfg.forgotPasswordUrl.endsWith('/CommunitiesForgotPassword'));
  }
}
