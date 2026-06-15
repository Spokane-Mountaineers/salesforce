import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getMembers from "@salesforce/apex/ActivityGroupController.getMembers";
import updateGroupDescription from "@salesforce/apex/ActivityGroupController.updateGroupDescription";
import removeMember from "@salesforce/apex/ActivityGroupController.removeMember";
import setJoinRequestStatus from "@salesforce/apex/ActivityGroupController.setJoinRequestStatus";

// Standardized activity-group admin panel: shown on the group page to the
// group's Chatter admin/owner. Lets a chair edit the group description and
// manage membership (approve/decline join requests, remove members) on-site.
// Event approvals stay in Salesforce (the per-group approval processes).
export default class GroupAdminPanel extends LightningElement {
  @api groupId;
  @api description;

  draftDescription = "";
  members = [];
  requests = [];
  message;
  busy = false;
  _wired;

  connectedCallback() {
    this.draftDescription = this.description || "";
  }

  @wire(getMembers, { groupId: "$groupId" })
  wiredMembers(result) {
    this._wired = result;
    if (result.data) {
      this.members = result.data.members;
      this.requests = result.data.requests;
    }
  }

  get hasRequests() {
    return this.requests.length > 0;
  }
  get hasMembers() {
    return this.members.length > 0;
  }

  handleDescChange(event) {
    this.draftDescription = event.target.value;
  }

  async saveDescription() {
    this.busy = true;
    this.message = undefined;
    try {
      await updateGroupDescription({
        groupId: this.groupId,
        description: this.draftDescription
      });
      this.message = "Group description saved.";
    } catch (e) {
      this.message = e?.body?.message || "Could not save the description.";
    } finally {
      this.busy = false;
    }
  }

  async handleRemove(event) {
    try {
      await removeMember({ memberRecordId: event.target.dataset.id });
      await refreshApex(this._wired);
    } catch (e) {
      this.message = e?.body?.message || "Could not remove that member.";
    }
  }

  async handleRequest(event) {
    const { id, status } = event.target.dataset;
    try {
      await setJoinRequestStatus({ requestId: id, status });
      await refreshApex(this._wired);
    } catch (e) {
      this.message = e?.body?.message || "Could not update that request.";
    }
  }
}
