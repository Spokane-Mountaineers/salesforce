import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getEvent from "@salesforce/apex/EventController.getEvent";
import rsvp from "@salesforce/apex/EventController.rsvp";

// Event detail + RSVP (plan §5.4). Wires getEvent (includes the member's current
// response + live attending count) and writes via EventController.rsvp, the LWC
// that replaces the Aura RSVP screen flow.
export default class EventDetail extends LightningElement {
  @api recordId;
  @api eventId;

  event;
  error;
  busy = false;
  message;
  _wired;

  get effectiveId() {
    return this.eventId || this.recordId;
  }

  @wire(getEvent, { eventId: "$effectiveId" })
  wiredEvent(result) {
    this._wired = result;
    if (result.data) {
      this.event = result.data;
      this.error = undefined;
    } else if (result.error) {
      this.error = result.error?.body?.message || "Could not load this event.";
      this.event = undefined;
    }
  }

  get hasEvent() {
    return Boolean(this.event);
  }

  get takesRsvp() {
    return this.event && this.event.registrationType !== "No RSVP";
  }

  get isAttending() {
    return this.event && this.event.myResponse === "Attending";
  }

  get rsvpLabel() {
    return this.isAttending ? "Cancel RSVP" : "RSVP — I'm going";
  }

  get rsvpVariant() {
    return this.isAttending
      ? "smi-btn smi-btn--ghost"
      : "smi-btn smi-btn--primary";
  }

  get spots() {
    if (!this.event) return "";
    const cap = this.event.limitOfAttendees;
    const count = this.event.attendingCount || 0;
    if (!cap || cap <= 0) return `${count} going`;
    return `${count} / ${cap} spots filled`;
  }

  get isFull() {
    const cap = this.event?.limitOfAttendees;
    return (
      !this.isAttending &&
      cap &&
      cap > 0 &&
      (this.event.attendingCount || 0) >= cap
    );
  }

  async handleRsvp() {
    this.busy = true;
    this.message = undefined;
    try {
      const result = await rsvp({
        eventId: this.effectiveId,
        attending: !this.isAttending
      });
      // Reflect the new state immediately, then refresh the wire for accuracy.
      this.event = {
        ...this.event,
        myResponse: result.response,
        attendingCount: result.attendingCount
      };
      this.message =
        result.response === "Attending"
          ? "You're on the list. See you out there."
          : "Your RSVP has been cancelled.";
      if (this._wired) {
        await refreshApex(this._wired);
      }
    } catch (e) {
      this.message = e?.body?.message || "Sorry — that didn't work.";
    } finally {
      this.busy = false;
    }
  }
}
