import { LightningElement, api, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getParticipants from "@salesforce/apex/CaseParticipantHelper.getParticipants";
import addParticipant from "@salesforce/apex/CaseParticipantHelper.addParticipant";
import removeParticipant from "@salesforce/apex/CaseParticipantHelper.removeParticipant";
import searchContacts from "@salesforce/apex/CaseParticipantHelper.searchContacts";

const LOG_PREFIX = "[ticketParticipants]";
const log = (...args) => console.log(LOG_PREFIX, ...args);
const warn = (...args) => console.warn(LOG_PREFIX, ...args);
const err = (...args) => console.error(LOG_PREFIX, ...args);

export default class TicketParticipants extends LightningElement {
  @api caseId;
  @api isOpener = false; // true if current user is the case opener

  @track isLoading = false;
  @track error;

  @track showAddModal = false;
  @track searchTerm = "";
  @track searchResults = [];
  @track isSearching = false;
  @track isAdding = false;
  @track confirmRemoveId = null; // participant Id awaiting inline confirmation

  wiredParticipantsResult;

  _rawParticipants = [];

  connectedCallback() {
    log(
      "connectedCallback | caseId:",
      this.caseId,
      "| isOpener:",
      this.isOpener
    );
  }

  @wire(getParticipants, { caseId: "$caseId" })
  wiredParticipants(result) {
    this.wiredParticipantsResult = result;
    const { data, error } = result;

    log(
      "wiredParticipants called | caseId:",
      this.caseId,
      "| data present:",
      !!data,
      "| error present:",
      !!error
    );

    if (data) {
      log("  wiredParticipants data received, count:", data.length);
      this._rawParticipants = data.map((p) => ({
        ...p,
        formattedAddedDate: p.Added_Date__c
          ? new Date(p.Added_Date__c).toLocaleDateString()
          : "",
        contactName: p.Contact__r ? p.Contact__r.Name : "Unknown Member"
      }));
      this.error = undefined;
      this.isLoading = false;
    } else if (error) {
      err("  wiredParticipants error:", error);
      err("  error body:", error?.body);
      err("  error message:", error?.body?.message);
      err("  error statusCode:", error?.body?.statusCode);

      if (error?.body?.message?.includes("not found or you do not have")) {
        warn(
          "  PERMISSION: User cannot view participants. They may not be on this Case, or Case_Participant__c FLS is missing."
        );
      }

      this.error = error.body?.message || "Unable to load participants";
      this._rawParticipants = [];
      this.isLoading = false;
    } else {
      log("  wiredParticipants pending");
      this.isLoading = true;
    }
  }

  get participants() {
    return this._rawParticipants.map((p) => ({
      ...p,
      isPendingRemove: p.Id === this.confirmRemoveId
    }));
  }

  get hasParticipants() {
    return this._rawParticipants.length > 0;
  }

  get isNotLoading() {
    return !this.isLoading;
  }

  get participantCount() {
    return this._rawParticipants.length;
  }

  // Opener or existing participants can add others
  get canAddParticipant() {
    return this.isOpener || this.participantCount > 0;
  }

  get hasSearchResults() {
    return this.searchResults && this.searchResults.length > 0;
  }

  get showNoResults() {
    return (
      !this.isSearching &&
      this.searchTerm.length >= 2 &&
      this.searchResults.length === 0
    );
  }

  handleOpenAddModal() {
    log("handleOpenAddModal called");
    this.showAddModal = true;
    this.searchTerm = "";
    this.searchResults = [];
  }

  handleCloseAddModal() {
    log("handleCloseAddModal called");
    this.showAddModal = false;
    this.searchTerm = "";
    this.searchResults = [];
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
    log("handleSearchChange, searchTerm:", this.searchTerm);

    if (this.searchTerm.length < 2) {
      this.searchResults = [];
      return;
    }

    this.isSearching = true;
    this.runSearch();
  }

  async runSearch() {
    log(
      "runSearch called, searchTerm:",
      this.searchTerm,
      "| caseId:",
      this.caseId
    );
    try {
      const results = await searchContacts({
        searchTerm: this.searchTerm,
        caseId: this.caseId
      });
      log("  searchContacts returned", results.length, "results");
      this.searchResults = results;
    } catch (error) {
      err("  searchContacts error:", error);
      err("  error body:", error?.body);
      this.searchResults = [];
    } finally {
      this.isSearching = false;
    }
  }

  async handleAddContact(event) {
    const contactId = event.currentTarget.dataset.contactId;
    const contactName = event.currentTarget.dataset.contactName;
    log(
      "handleAddContact called | contactId:",
      contactId,
      "| contactName:",
      contactName
    );

    this.isAdding = true;
    try {
      await addParticipant({ caseId: this.caseId, contactId });
      log("  addParticipant succeeded");
      this.showToast(
        "Success",
        `${contactName} has been added as a participant.`,
        "success"
      );
      this.handleCloseAddModal();
      await refreshApex(this.wiredParticipantsResult);
      this.dispatchEvent(new CustomEvent("participantadded"));
    } catch (error) {
      err("  addParticipant error:", error);
      err("  error body:", error?.body);
      const message = error.body?.message || "Failed to add participant.";
      this.showToast("Error", message, "error");
    } finally {
      this.isAdding = false;
    }
  }

  handleRemoveParticipant(event) {
    // First click: show inline confirm row; second click (confirmRemove) executes.
    const participantId = event.currentTarget.dataset.participantId;
    log(
      "handleRemoveParticipant called, showing confirm for participantId:",
      participantId
    );
    this.confirmRemoveId = participantId;
  }

  handleCancelRemove() {
    log("handleCancelRemove called");
    this.confirmRemoveId = null;
  }

  async handleConfirmRemove(event) {
    const participantId = event.currentTarget.dataset.participantId;
    const contactName = event.currentTarget.dataset.contactName;
    log(
      "handleConfirmRemove called | participantId:",
      participantId,
      "| contactName:",
      contactName
    );
    this.confirmRemoveId = null;

    try {
      await removeParticipant({ participantId });
      log("  removeParticipant succeeded");
      this.showToast("Success", `${contactName} has been removed.`, "success");
      await refreshApex(this.wiredParticipantsResult);
      this.dispatchEvent(new CustomEvent("participantremoved"));
    } catch (error) {
      err("  removeParticipant error:", error);
      err("  error body:", error?.body);
      const message = error.body?.message || "Failed to remove participant.";
      this.showToast("Error", message, "error");
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
