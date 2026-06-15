import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import isGuest from "@salesforce/user/isGuest";
import basePath from "@salesforce/community/basePath";
import getGroup from "@salesforce/apex/ActivityGroupController.getGroup";
import joinGroup from "@salesforce/apex/ActivityGroupController.joinGroup";
import leaveGroup from "@salesforce/apex/ActivityGroupController.leaveGroup";
import setNotificationFrequency from "@salesforce/apex/ActivityGroupController.setNotificationFrequency";

const FREQUENCIES = [
  { value: "P", label: "Every post" },
  { value: "D", label: "Daily digest" },
  { value: "W", label: "Weekly digest" },
  { value: "N", label: "Never" }
];

// Activity-group page: group header + membership controls (join/leave, email
// notification frequency) + the group's events + its feed. The id arrives as the
// ?recordId= URL param. Chairs still approve events in Salesforce; this page is
// read/browse + self-service membership. New members default to a daily digest.
export default class GroupDetail extends LightningElement {
  @api recordId;
  @api groupId;

  urlRecordId;
  group;
  errorMessage;
  busy = false;
  _wired;

  @wire(CurrentPageReference)
  setPageRef(pageRef) {
    this.urlRecordId = pageRef?.state?.recordId;
  }

  get effectiveId() {
    return this.groupId || this.urlRecordId || this.recordId;
  }

  @wire(getGroup, { groupId: "$effectiveId" })
  wiredGroup(result) {
    this._wired = result;
    if (result.data) {
      this.group = result.data;
      this.errorMessage = undefined;
    } else if (result.error) {
      this.errorMessage =
        result.error?.body?.message || "This group could not be loaded.";
      this.group = undefined;
    }
  }

  get isGuest() {
    return isGuest;
  }
  get hasGroup() {
    return Boolean(this.group);
  }
  get typeLabel() {
    return this.group?.isPublic ? "Public group" : "Private group";
  }
  get memberLabel() {
    if (!this.group) return "";
    const n = this.group.memberCount;
    return `${n} ${n === 1 ? "member" : "members"}`;
  }
  get backUrl() {
    return `${basePath}/activities`;
  }

  // Membership state
  get isMember() {
    return Boolean(this.group?.isMember);
  }
  get notMember() {
    return !this.isMember;
  }
  get showJoin() {
    return this.group && !this.group.isMember && !this.group.hasPendingRequest;
  }
  get joinLabel() {
    return this.group?.isPublic ? "Join group" : "Request to join";
  }
  get showPending() {
    return Boolean(this.group?.hasPendingRequest);
  }

  // Notification frequency select (current value preselected).
  get frequencyOptions() {
    const current = this.group?.notificationFrequency || "D";
    return FREQUENCIES.map((f) => ({ ...f, selected: f.value === current }));
  }

  async handleJoin() {
    this.busy = true;
    try {
      await joinGroup({ groupId: this.group.id });
      await refreshApex(this._wired);
    } catch (e) {
      this.errorMessage = e?.body?.message || "Could not join the group.";
    } finally {
      this.busy = false;
    }
  }

  async handleLeave() {
    this.busy = true;
    try {
      await leaveGroup({ groupId: this.group.id });
      await refreshApex(this._wired);
    } catch (e) {
      this.errorMessage = e?.body?.message || "Could not leave the group.";
    } finally {
      this.busy = false;
    }
  }

  async handleFrequencyChange(event) {
    const frequency = event.target.value;
    try {
      await setNotificationFrequency({ groupId: this.group.id, frequency });
    } catch (e) {
      this.errorMessage =
        e?.body?.message || "Could not update your notifications.";
    }
  }
}
