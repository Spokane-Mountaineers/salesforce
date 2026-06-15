import { LightningElement, wire } from "lwc";
import basePath from "@salesforce/community/basePath";
import getGroups from "@salesforce/apex/ActivityGroupController.getGroups";

// Activities directory: a dynamic, club-managed list of activity groups
// (CollaborationGroups). Each links to its group page. No hardcoded groups —
// bespoke groups appear automatically because this is data, not code.
export default class GroupDirectory extends LightningElement {
  groups = [];
  error;
  loaded = false;

  @wire(getGroups)
  wired({ data, error }) {
    if (data) {
      this.groups = data.map((g) => ({
        ...g,
        url: `${basePath}/group?recordId=${g.id}`,
        memberLabel: `${g.memberCount} ${
          g.memberCount === 1 ? "member" : "members"
        }`,
        typeLabel: g.isPublic ? "Public" : "Private",
        typeClass: g.isPublic ? "tag tag--public" : "tag tag--private"
      }));
      this.error = undefined;
      this.loaded = true;
    } else if (error) {
      this.error =
        error?.body?.message || "Could not load activity groups right now.";
      this.loaded = true;
    }
  }

  // The core club activity groups stay featured up top (they're the ones with
  // the formal event-approval workflow); everything else lists below.
  get coreGroups() {
    return this.groups.filter((g) => g.isCore);
  }
  get otherGroups() {
    return this.groups.filter((g) => !g.isCore);
  }
  get hasCore() {
    return this.coreGroups.length > 0;
  }
  get hasOthers() {
    return this.otherGroups.length > 0;
  }
  get hasGroups() {
    return this.groups.length > 0;
  }
  get hasError() {
    return Boolean(this.error);
  }
  get isEmpty() {
    return this.loaded && !this.error && this.groups.length === 0;
  }
}
