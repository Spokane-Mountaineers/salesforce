import { LightningElement, api, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import basePath from "@salesforce/community/basePath";
import getGroup from "@salesforce/apex/ActivityGroupController.getGroup";

// Activity-group page: group header + that group's upcoming events (the events
// calendar preset to this group). The id arrives as the ?recordId= URL param.
// Chairs still manage membership and approve events in Salesforce — this page is
// read-only over the group; members create events via the calendar/new-event
// flow, which routes to the chair's approval process.
export default class GroupDetail extends LightningElement {
  @api recordId;
  @api groupId;

  urlRecordId;
  group;
  errorMessage;

  @wire(CurrentPageReference)
  setPageRef(pageRef) {
    this.urlRecordId = pageRef?.state?.recordId;
  }

  get effectiveId() {
    return this.groupId || this.urlRecordId || this.recordId;
  }

  @wire(getGroup, { groupId: "$effectiveId" })
  wiredGroup({ data, error }) {
    if (data) {
      this.group = data;
      this.errorMessage = undefined;
    } else if (error) {
      this.errorMessage =
        error?.body?.message || "This group could not be loaded.";
      this.group = undefined;
    }
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
}
