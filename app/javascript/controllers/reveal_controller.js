import { Controller } from "@hotwired/stimulus"

// Banking-app style "hide sensitive value by default" toggle. The real
// value is embedded in a data attribute (still present in the page's own
// HTML — this is the account holder's own data on their own authenticated
// page, not exposed to anyone else) and only swapped into view on click.
export default class extends Controller {
  static targets = ["display", "showIcon", "hideIcon"]
  static values = { text: String, mask: { type: String, default: "••••••" } }

  connect() {
    this.visible = false
  }

  toggle() {
    this.visible = !this.visible
    this.displayTarget.textContent = this.visible ? this.textValue : this.maskValue
    this.showIconTarget.classList.toggle("hidden", this.visible)
    this.hideIconTarget.classList.toggle("hidden", !this.visible)
  }
}
