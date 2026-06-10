/**
 * @AuraEnabled login controller for the LWR site's custom login LWC (plan §8).
 *
 * Ports the working CommunitiesLoginController behaviour — the `.smi` username
 * normalization (email-based login) and the Google/Microsoft SSO + forgot/admin
 * URLs — into a shape an LWC can call. `without sharing` so it can read Network/
 * Site and run Site.login. Site.login authenticates and returns a redirect URL;
 * the LWC sends the browser there.
 */
public without sharing class CommunityLoginController {
  /** Authenticate with username + password; returns a redirect URL on success. */
  @AuraEnabled
  public static LoginResult login(
    String username,
    String password,
    String startUrl
  ) {
    LoginResult res = new LoginResult();
    if (String.isBlank(username) || String.isBlank(password)) {
      res.message = 'Please enter both your username and password.';
      return res;
    }
    try {
      String normalized = normalizeUsername(username.trim());
      String dest = String.isBlank(startUrl) ? defaultStartUrl() : startUrl;
      PageReference pr = Site.login(normalized, password, dest);
      if (pr != null) {
        res.success = true;
        res.redirectUrl = pr.getUrl();
      } else {
        res.message = 'Invalid username or password. Please try again.';
      }
    } catch (Exception e) {
      res.message = 'Something went wrong signing you in. Please try again.';
    }
    return res;
  }

  /** SSO + helper URLs for the login UI. */
  @AuraEnabled(cacheable=true)
  public static LoginConfig getLoginConfig() {
    LoginConfig cfg = new LoginConfig();
    String base = Site.getBaseUrl();
    if (String.isBlank(base)) {
      base = '';
    }
    cfg.googleUrl = base + '/services/auth/sso/Google';
    cfg.microsoftUrl = base + '/services/auth/sso/Microsoft';
    cfg.forgotPasswordUrl = base + '/CommunitiesForgotPassword';
    return cfg;
  }

  /** `.smi` suffix lets members sign in with just their email (ported logic). */
  @TestVisible
  private static String normalizeUsername(String rawUsername) {
    if (String.isBlank(rawUsername)) {
      return rawUsername;
    }
    return rawUsername.endsWithIgnoreCase('.smi')
      ? rawUsername
      : rawUsername + '.smi';
  }

  private static String defaultStartUrl() {
    return '/s/';
  }

  public class LoginResult {
    @AuraEnabled
    public Boolean success = false;
    @AuraEnabled
    public String redirectUrl;
    @AuraEnabled
    public String message;
  }

  public class LoginConfig {
    @AuraEnabled
    public String googleUrl;
    @AuraEnabled
    public String microsoftUrl;
    @AuraEnabled
    public String forgotPasswordUrl;
  }
}
