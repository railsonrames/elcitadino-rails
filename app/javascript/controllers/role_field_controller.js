import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clientLabel", "providerLabel"]

  toggle(event) {
    const isProvider = event.target.value === "provider"
    this.clientLabelTarget.classList.toggle("hidden", isProvider)
    this.providerLabelTarget.classList.toggle("hidden", !isProvider)
  }
}
