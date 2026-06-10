import { LightningElement, api, wire, track } from "lwc";

import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import getTicketDetails from "@salesforce/apex/TicketQueryHelper.getTicketDetails";
import getTicketComments from "@salesforce/apex/TicketQueryHelper.getTicketComments";
import addComment from "@salesforce/apex/TicketSubmissionHelper.addComment";
import reopenTicket from "@salesforce/apex/TicketSubmissionHelper.reopenTicket";
import getContactForUser from "@salesforce/apex/TicketSubmissionHelper.getContactForUser";

const LOG_PREFIX = "[ticketDetail]";
const log = (...args) => console.log(LOG_PREFIX, ...args);
const warn = (...args) => console.warn(LOG_PREFIX, ...args);
const err = (...args) => console.error(LOG_PREFIX, ...args);

export default class TicketDetail extends NavigationMixin(LightningElement) {
  @api recordId;
  @track ticket;
  @track comments = [];
  @track files = [];
  @track newComment = "";
  @track isLoading = false;
  @track isAddingComment = false;
  @track isReopening = false;
  @track error;
  @track _urlCaseId;
  @track _currentContactId;
  @track _initialized = false;

  wiredTicketResult;
  wiredCommentsResult;

  acceptedFormats = [
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
    ".doc",
    ".docx",
    ".txt",
    ".csv",
    ".xlsx"
  ];

  connectedCallback() {
    log("connectedCallback start");
    log("  window.location.href:", window.location.href);
    log("  window.location.pathname:", window.location.pathname);
    log("  window.location.search:", window.location.search);
    log("  @api recordId:", this.recordId);

    this.isLoading = true;

    if (!this.recordId) {
      log("  recordId not set via @api, attempting URL extraction");
      try {
        const urlParams = new URLSearchParams(window.location.search);
        log("  URL params parsed:", Object.fromEntries(urlParams.entries()));

        let caseId =
          urlParams.get("id") ||
          urlParams.get("caseId") ||
          urlParams.get("recordId");

        log("  caseId from query string:", caseId);

        if (!caseId) {
          const urlPath = window.location.pathname;
          const pathParts = urlPath
            .split("/")
            .filter((part) => part.length > 0);
          log("  path parts:", pathParts);

          let ticketIndex = pathParts.indexOf("ticket");
          if (ticketIndex < 0) {
            ticketIndex = pathParts.indexOf("ticket-detail");
          }
          log("  ticketIndex in path:", ticketIndex);

          if (ticketIndex >= 0 && pathParts[ticketIndex + 1]) {
            caseId = pathParts[ticketIndex + 1];
            log("  caseId extracted from path:", caseId);
          }
        }

        const idRegex = /^[a-zA-Z0-9]{15,18}$/;
        log(
          "  caseId regex valid?",
          caseId ? idRegex.test(caseId) : "n/a (no caseId)"
        );

        if (caseId && idRegex.test(caseId)) {
          this._urlCaseId = caseId;
          log("  _urlCaseId set to:", this._urlCaseId);
        } else {
          warn(
            "  No valid caseId found in URL. Page will show no ticket data."
          );
        }
      } catch (e) {
        err("  Exception during URL parsing:", e);
      }
    } else {
      log("  Using @api recordId:", this.recordId);
    }

    log("  Calling getContactForUser...");
    getContactForUser()
      .then((contactId) => {
        log("  getContactForUser resolved, contactId:", contactId);
        if (!contactId) {
          warn(
            "  getContactForUser returned null. User has no linked Contact. Wire queries will find no matching Cases."
          );
        }
        this._currentContactId = contactId;
      })
      .catch((e) => {
        err("  getContactForUser rejected:", e);
        err("  error body:", e?.body);
        err("  error message:", e?.body?.message || e?.message);
      })
      .finally(() => {
        this._initialized = true;
        log(
          "  _initialized set to true. resolvedCaseId:",
          this.resolvedCaseId,
          "| _caseIdForWire will now return:",
          this.resolvedCaseId || null
        );
      });
  }

  get resolvedCaseId() {
    return this.recordId || this._urlCaseId;
  }

  // Reactive param used by @wire; returns null until initialized with a valid Id
  get _caseIdForWire() {
    const id = this.resolvedCaseId;
    const value = this._initialized && id ? id : null;
    log(
      "  _caseIdForWire evaluated | _initialized:",
      this._initialized,
      "| resolvedCaseId:",
      id,
      "| result:",
      value
    );
    return value;
  }

  get hasCaseId() {
    return !!this._caseIdForWire;
  }

  @wire(getTicketDetails, { caseId: "$_caseIdForWire" })
  wiredTicket(result) {
    this.wiredTicketResult = result;
    const { data, error } = result;

    log(
      "wiredTicket called | data present:",
      !!data,
      "| error present:",
      !!error
    );

    if (data) {
      log("  wiredTicket data received:", JSON.parse(JSON.stringify(data)));
      log("  RecordType:", data.RecordType);
      log("  Owner:", data.Owner);
      log("  Contact:", data.Contact);
      log("  Related_User__c:", data.Related_User__c);

      this.ticket = {
        ...data,
        formattedCreatedDate: this.formatDateValue(data.CreatedDate),
        formattedLastModifiedDate: this.formatDateValue(data.LastModifiedDate),
        statusBadgeVariant: this.getStatusBadgeVariant(data.Status),
        priorityBadgeVariant: this.getPriorityBadgeVariant(data.Priority),
        recordTypeName: data.RecordType ? data.RecordType.Name : "Standard",
        ownerName: data.Owner ? data.Owner.Name : "Unassigned"
      };
      this.error = undefined;
      this.isLoading = false;
      log("  ticket state set. Status:", this.ticket.Status);
    } else if (error) {
      err("  wiredTicket error:", error);
      err("  error body:", error?.body);
      err("  error message:", error?.body?.message);
      err("  error statusCode:", error?.body?.statusCode);
      err("  error stackTrace:", error?.body?.stackTrace);

      if (error?.body?.message?.includes("not found or you do not have")) {
        warn(
          "  PERMISSION: User Contact is not the Case opener and not a participant, OR Case does not exist with this ID."
        );
      }
      if (error?.body?.message?.includes("Error retrieving ticket details")) {
        warn(
          "  APEX EXCEPTION: Check FLS on Case fields. Related_User__c and Contact.User_Lookup__c may not be visible to this profile."
        );
      }

      this.error = error.body?.message || "Unable to load ticket details";
      this.ticket = undefined;
      this.isLoading = false;
    } else {
      log("  wiredTicket pending, no data or error yet");
      this.isLoading = true;
    }
  }

  @wire(getTicketComments, { caseId: "$_caseIdForWire" })
  wiredComments(result) {
    this.wiredCommentsResult = result;
    const { data, error } = result;

    log(
      "wiredComments called | data present:",
      !!data,
      "| error present:",
      !!error
    );

    if (data) {
      log("  wiredComments data received, count:", data.length);
      this.comments = data.map((comment) => ({
        ...comment,
        formattedCreatedDate: this.formatLongDateValue(comment.CreatedDate),
        createdByName: comment.CreatedBy ? comment.CreatedBy.Name : "System"
      }));
    } else if (error) {
      err("  wiredComments error:", error);
      err("  error body:", error?.body);
      err("  error message:", error?.body?.message);
    }
  }

  // Determines if current user is the case opener (to show Add Participant button)
  get isOpener() {
    if (!this.ticket || !this._currentContactId) return false;
    return (
      this.ticket.Contact?.Id === this._currentContactId ||
      this.ticket.ContactId === this._currentContactId
    );
  }

  handleCommentChange(event) {
    this.newComment = event.target.value;
  }

  async handleAddComment() {
    log(
      "handleAddComment called, comment length:",
      this.newComment?.trim()?.length
    );

    if (!this.newComment || this.newComment.trim().length === 0) {
      this.showToast("Error", "Please enter a comment.", "error");
      return;
    }

    const caseId = this.resolvedCaseId;
    if (!caseId) {
      this.showToast("Error", "Ticket ID is missing.", "error");
      return;
    }

    this.isAddingComment = true;
    this.error = null;

    try {
      log("  addComment apex call, caseId:", caseId);
      await addComment({ caseId, commentBody: this.newComment.trim() });
      log("  addComment succeeded");
      this.showToast("Success", "Comment added successfully.", "success");
      this.newComment = "";
      await refreshApex(this.wiredCommentsResult);
      await refreshApex(this.wiredTicketResult);
    } catch (error) {
      err("  addComment error:", error);
      this.error =
        error.body?.message ||
        error.message ||
        "An error occurred while adding your comment.";
      this.showToast("Error", this.error, "error");
    } finally {
      this.isAddingComment = false;
    }
  }

  async handleReopenTicket() {
    const caseId = this.resolvedCaseId;
    log("handleReopenTicket called, caseId:", caseId);
    if (!caseId) return;

    this.isReopening = true;
    try {
      await reopenTicket({ caseId });
      log("  reopenTicket succeeded");
      this.showToast("Success", "Ticket has been reopened.", "success");
      await refreshApex(this.wiredTicketResult);
    } catch (error) {
      err("  reopenTicket error:", error);
      const message = error.body?.message || "Failed to reopen ticket.";
      this.showToast("Error", message, "error");
    } finally {
      this.isReopening = false;
    }
  }

  handleFileUpload(event) {
    const uploadedFiles = event.detail.files;
    log("handleFileUpload called, files:", uploadedFiles?.length);
    if (uploadedFiles && uploadedFiles.length > 0) {
      this.showToast(
        "Success",
        `${uploadedFiles.length} file(s) uploaded successfully.`,
        "success"
      );
      // Refresh file list by rebuilding from event detail
      const newFiles = uploadedFiles.map((f) => ({
        Id: f.documentId,
        Title: f.name,
        downloadUrl: `/sfc/servlet.shepherd/document/download/${f.documentId}`,
        formattedDate: new Date().toLocaleDateString()
      }));
      this.files = [...this.files, ...newFiles];
    }
  }

  handleParticipantChange() {
    log("handleParticipantChange called, refreshing ticket data");
    // Refresh ticket data when participants change (in case sharing state affects anything)
    refreshApex(this.wiredTicketResult);
  }

  async handleRefresh() {
    log("handleRefresh called");
    this.isLoading = true;
    try {
      await Promise.all([
        refreshApex(this.wiredTicketResult),
        refreshApex(this.wiredCommentsResult)
      ]);
      log("  handleRefresh succeeded");
      this.showToast("Success", "Ticket refreshed.", "success");
    } catch (error) {
      err("  handleRefresh error:", error);
      this.showToast(
        "Error",
        "Unable to refresh ticket. Please try again.",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  handleBack() {
    log("handleBack called");
    this[NavigationMixin.Navigate](
      {
        type: "standard__webPage",
        attributes: { url: "/support/my-tickets" }
      },
      false
    );
  }

  get canAddComment() {
    return (
      this.ticket &&
      this.ticket.Status !== "Closed" &&
      this.ticket.Status !== "Resolved" &&
      this.newComment &&
      this.newComment.trim().length > 0 &&
      !this.isAddingComment
    );
  }

  get isAddCommentDisabled() {
    return !this.canAddComment;
  }

  get isTicketClosed() {
    return (
      this.ticket &&
      (this.ticket.Status === "Closed" || this.ticket.Status === "Resolved")
    );
  }

  get hasFiles() {
    return this.files && this.files.length > 0;
  }

  get hasComments() {
    return this.comments && this.comments.length > 0;
  }

  get commentCount() {
    return this.comments ? this.comments.length : 0;
  }

  get statusBadgeVariant() {
    if (!this.ticket) return "default";
    return this.getStatusBadgeVariant(this.ticket.Status);
  }

  getStatusBadgeVariant(status) {
    if (status === "Closed" || status === "Resolved") return "success";
    if (status === "In Progress" || status === "Waiting for Member")
      return "warning";
    return "info";
  }

  getPriorityBadgeVariant(priority) {
    if (!priority) return "default";
    if (priority === "High") return "error";
    if (priority === "Medium") return "warning";
    return "default";
  }

  formatDateValue(dateValue) {
    if (!dateValue) return "";
    const date = new Date(dateValue);
    return date.toLocaleDateString() + " " + date.toLocaleTimeString();
  }

  formatLongDateValue(dateValue) {
    if (!dateValue) return "";
    return new Date(dateValue).toLocaleString();
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
