/**
 * Controller for custom Community login page with username normalization.
 * Automatically appends .smi suffix to usernames to support email-based login.
 *
 * @author Spokane Mountaineers
 * @date 2026-02-05
 */
public without sharing class CommunitiesLoginController {
  // Form inputs
  public String username { get; set; }
  public String password { get; set; }

  // Page state
  public String startUrl { get; set; }
  public Boolean hasError { get; set; }

  /**
   * Constructor - Initialize page state and capture startURL parameter
   */
  public CommunitiesLoginController() {
    this.hasError = false;
    this.startUrl = System.currentPageReference()
      .getParameters()
      .get('startURL');

    // Default to community home if no startURL provided
    if (String.isBlank(this.startUrl)) {
      this.startUrl = getDefaultStartUrl();
    }
  }

  /**
   * Get the default start URL for the community
   * Ensures we point to the /s/ path which is the home for Experience Builder sites.
   * Uses the /servlet/networks/switch endpoint to force the community context
   * for all users, including administrators who might otherwise be redirected to LEX.
   *
   * @return Default community start URL (switch path)
   */
  private String getDefaultStartUrl() {
    String networkId = getNetworkId();
    if (String.isNotBlank(networkId)) {
      return '/servlet/networks/switch?networkId=' +
        networkId +
        '&startURL=' +
        EncodingUtil.urlEncode('/s/', 'UTF-8');
    }
    return '/s/';
  }

  /**
   * Helper to retrieve the Network ID for the Spokane Mountaineers community
   *
   * @return Network ID or null if not found
   */
  private String getNetworkId() {
    try {
      // Query the Network ID for the main community
      // Using 'without sharing' controller allows access to this record
      List<Network> networks = [
        SELECT Id
        FROM Network
        WHERE Name = 'Spokane Mountaineers'
        LIMIT 1
      ];
      if (!networks.isEmpty()) {
        return networks[0].Id;
      }
    } catch (Exception e) {
      // Log error or handle gracefully
    }
    return null;
  }

  /**
   * Handle login form submission
   * Normalizes username by appending .smi suffix if not present and authenticates user
   *
   * @return PageReference to redirect after successful login, null on error
   */
  public PageReference login() {
    try {
      // Validate inputs
      if (String.isBlank(username) || String.isBlank(password)) {
        ApexPages.addMessage(
          new ApexPages.Message(
            ApexPages.Severity.ERROR,
            'Please enter both username and password.'
          )
        );
        this.hasError = true;
        return null;
      }

      // Normalize username: append .smi suffix if not present
      String normalizedUsername = normalizeUsername(username.trim());

      // Attempt authentication with normalized username
      PageReference result = Site.login(normalizedUsername, password, startUrl);

      // If login successful, Site.login returns a PageReference
      // If failed, it returns null
      if (result != null) {
        return result;
      } else {
        ApexPages.addMessage(
          new ApexPages.Message(
            ApexPages.Severity.ERROR,
            'Invalid username or password. Please try again.'
          )
        );
        this.hasError = true;
        return null;
      }
    } catch (Exception e) {
      ApexPages.addMessage(
        new ApexPages.Message(
          ApexPages.Severity.ERROR,
          'An error occurred during login. Please try again.'
        )
      );
      this.hasError = true;
      return null;
    }
  }

  /**
   * Normalize username by appending .smi suffix if not present
   * Allows users to login with just their email address
   *
   * @param rawUsername The username entered by user
   * @return Normalized username with .smi suffix
   */
  @TestVisible
  private String normalizeUsername(String rawUsername) {
    if (String.isBlank(rawUsername)) {
      return rawUsername;
    }

    // Append .smi suffix if not already present (case insensitive)
    if (!rawUsername.endsWithIgnoreCase('.smi')) {
      return rawUsername + '.smi';
    }

    return rawUsername;
  }

  /**
   * Get the forgot password URL for the community
   * Returns the direct path to the CommunitiesForgotPassword Visualforce page
   *
   * Note: We use the direct Visualforce page path instead of the generic /ForgotPassword
   * route due to a known Salesforce platform limitation where Experience Cloud's Login &
   * Registration settings don't reliably override authentication routes for Visualforce pages.
   *
   * @return URL to forgot password page
   */
  public String getForgotPasswordUrl() {
    String communityUrl = Site.getBaseUrl();
    if (String.isNotBlank(communityUrl)) {
      return communityUrl + '/CommunitiesForgotPassword';
    }
    return '/CommunitiesForgotPassword';
  }

  /**
   * Get the Google OAuth login URL
   * This is configured in Setup > Auth Providers > Google
   *
   * @return URL to initiate Google OAuth flow
   */
  public String getGoogleLoginUrl() {
    // Get the current site's base URL
    String communityUrl = Site.getBaseUrl();

    // Construct Google auth URL
    // Format: /services/auth/sso/Google?startURL={startUrl}
    String googleUrl = communityUrl + '/services/auth/sso/Google';

    if (String.isNotBlank(startUrl)) {
      googleUrl += '?startURL=' + EncodingUtil.urlEncode(startUrl, 'UTF-8');
    }

    return googleUrl;
  }

  /**
   * Get the Microsoft OAuth login URL
   * This is configured in Setup > Auth Providers > Microsoft (URL Suffix: Microsoft)
   * Backed by the Microsoft Entra App Registration managed in the
   * Spokane-Mountaineers/infrastructure repository.
   *
   * @return URL to initiate Microsoft OAuth flow
   */
  public String getMicrosoftLoginUrl() {
    String communityUrl = Site.getBaseUrl();

    // Format: /services/auth/sso/Microsoft?startURL={startUrl}
    String microsoftUrl = communityUrl + '/services/auth/sso/Microsoft';

    if (String.isNotBlank(startUrl)) {
      microsoftUrl += '?startURL=' + EncodingUtil.urlEncode(startUrl, 'UTF-8');
    }

    return microsoftUrl;
  }

  /**
   * Get the admin/internal Salesforce login URL
   * This allows system admins to access the internal org from the community login page.
   * Uses the networks session create endpoint to ensure the user is logged into
   * the community context after authenticating with their internal credentials.
   *
   * @return URL to internal Salesforce employee login
   */
  public String getAdminLoginUrl() {
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();
    String siteId = Site.getSiteId();

    if (String.isBlank(siteId)) {
      try {
        List<Site> sites = [
          SELECT Id
          FROM Site
          WHERE Name = 'Spokane_Mountaineers'
          LIMIT 1
        ];
        if (!sites.isEmpty()) {
          siteId = sites[0].Id;
        }
      } catch (Exception e) {
        // Handle gracefully
      }
    }

    String sessionCreateUrl = orgUrl + '/servlet/networks/session/create';

    if (String.isNotBlank(siteId)) {
      String shortSiteId = siteId.length() >= 15
        ? siteId.substring(0, 15)
        : siteId;
      sessionCreateUrl += '?site=' + shortSiteId;

      String destUrl = String.isNotBlank(startUrl) ? startUrl : '/s/';

      // Extract the real destination if startUrl is the switch servlet
      if (destUrl.contains('/servlet/networks/switch') && destUrl.contains('startURL=')) {
        Integer startIndex = destUrl.indexOf('startURL=') + 9;
        String encodedInnerUrl = destUrl.substring(startIndex);
        if (encodedInnerUrl.contains('&')) {
          encodedInnerUrl = encodedInnerUrl.substring(0, encodedInnerUrl.indexOf('&'));
        }
        destUrl = EncodingUtil.urlDecode(encodedInnerUrl, 'UTF-8');
      }

      sessionCreateUrl += '&url=' + EncodingUtil.urlEncode(destUrl, 'UTF-8');
    }

    return sessionCreateUrl;
  }
}
