import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview"]

  format() {
    this.inputTarget.value = this.inputTarget.value.toLowerCase()
    this.previewTarget.textContent = this.inputTarget.value
  }
}
